import { AppError } from '../../shared/errors.js';
import { distanceMeters, type LatLon, SECTOR_SIZE_M, sectorOf } from '../../shared/geo.js';
import { publicSector } from '../matching/service.js';
import type { RouteResult, RoutingProvider } from '../../shared/routing/routing-provider.js';
import { estimatePrice, type PriceEstimate, proRataPrice } from '../pricing/domain.js';
import type { Notifier } from '../../shared/notifications/notifier.js';
import { parisDateOf, parisTimeOf } from '../../shared/time.js';
import type { SettingsService } from '../settings/service.js';
import { type Direction, onboardDistances, orderStops, passageTimes, planKey, shiftedPassages } from './domain.js';
import { type HistoryRow, isAccepted, type Member, pickupOf, type RideInfo, type RidesRepo } from './repo.js';

const VISIBLE_STATUSES = new Set(['confirmed', 'in_progress', 'completed']);
/** Participants dont le domicile entre dans l'aperçu d'un trajet (proposés, demandes, acceptés). */
const PREVIEW_STATUSES = new Set(['proposed', 'requested', 'accepted', 'picked_up']);
const PREVIEW_CACHE_SIZE = 200;
const LOCKED_STATUSES = new Set(['in_progress', 'completed', 'cancelled']);

export interface StopView {
  order: number;
  kind: 'driver' | 'passenger' | 'campus';
  userId: string | null;
  firstName: string | null;
  /** Débloqué seulement entre personnes qui se sont acceptées (conducteur ↔ passager). */
  lastName: string | null;
  label: string;
  lat: number;
  lon: number;
  eta: Date | null;
  isMeetingPoint: boolean;
  /** Point approximatif (centre du secteur) : à montrer comme une zone, jamais comme une adresse. */
  approximate: boolean;
  /** Passager : monté (signalé par le conducteur), présence validée par proximité. */
  pickedUp: boolean;
  presenceValidated: boolean;
  /** Passager arrivé à destination (suivi). */
  arrived: boolean;
  /** Passager qui a terminé son trajet, arrivé ou parti avant (clôture de sa part). */
  ended: boolean;
}

export interface PriceView extends PriceEstimate {
  /** Toujours une estimation avant la clôture (cahier §5). */
  estimated: true;
  youPayCents: number | null;
  youReceiveCents: number | null;
  /** Passager : distance à bord ; sa part du carburant est au prorata (cahier §5). */
  myDistanceM: number | null;
  /** Détail du calcul : consommation, prix du litre, portions (à bord : passagers + conducteur). */
  breakdown: {
    consumptionLPer100km: number;
    fuelPriceCentsPerLitre: number;
    distanceM: number;
    /** Passager : ses portions ; conducteur : toutes. `persons` : conducteur compris. */
    portions: { distanceM: number; persons: number }[];
    /** Conducteur : part de chaque passager. */
    shares: { userId: string; firstName: string; shareCents: number }[];
  } | null;
}

/** Aperçu d'un trajet pas encore confirmé : tracé sans les abords des domiciles des autres. */
export interface RidePreview {
  route: [number, number][];
  estimated: boolean;
  campus: LatLon & { name: string };
  /** Mon point de prise en charge (ou de dépose), le seul exact. */
  me: LatLon | null;
}

export interface RideView {
  id: string;
  day: string;
  direction: Direction;
  time: Date;
  status: string;
  role: 'driver' | 'passenger';
  myStatus: string;
  seatsTotal: number;
  vehicle: { model: string | null; color: string | null } | null;
  distanceM: number | null;
  durationS: number | null;
  routeEstimated: boolean;
  route: [number, number][];
  stops: StopView[];
  price: PriceView | null;
}

/**
 * Trajets confirmés (cahier §5, §14) : plan (ordre des arrêts, tracé, heures de passage),
 * prix estimé, point de rendez-vous. Seuls les participants acceptés y ont accès.
 */
export class RidesService {
  constructor(
    private readonly repo: RidesRepo,
    private readonly routing: RoutingProvider,
    private readonly settings: SettingsService,
    private readonly clock: () => Date,
    /** Un vrai fournisseur existe : un plan estimé (panne, quota) sera recalculé plus tard. */
    private readonly retryEstimated = false,
    private readonly notifier?: Notifier,
  ) {}

  /** Tracés d'aperçu déjà calculés (mêmes points) : un seul appel d'itinéraire par jeu de points. */
  private readonly previews = new Map<string, RouteResult>();

  /** Adresse d'un participant modifiée : ses trajets confirmés à venir sont recalculés. */
  async onUserChanged(userId: string): Promise<void> {
    for (const rideId of await this.repo.upcomingConfirmedRides(userId, parisDateOf(this.clock()))) {
      await this.onRideChanged(rideId);
    }
  }

  /** Arrêts d'un trajet confirmé modifiés : nouveau plan. Une erreur laisse le plan à recalculer. */
  async onRideChanged(rideId: string): Promise<void> {
    await this.repo.invalidatePlan(rideId);
    const ride = await this.repo.ride(rideId);
    if (ride && VISIBLE_STATUSES.has(ride.status)) await this.plan(rideId);
  }

  /**
   * Calcule le plan hors transaction (appel externe), puis l'enregistre seulement si les
   * passagers et leurs points n'ont pas changé entre-temps (sinon le calcul suivant gagne).
   */
  private async plan(rideId: string): Promise<void> {
    const ride = await this.repo.ride(rideId);
    if (!ride) return;
    const members = await this.repo.members(rideId);
    const inputs = planInputs(ride, members);
    if (!inputs) return;
    const ordered = orderStops(inputs.start, inputs.end, inputs.stops);
    const route = await this.routing.route([inputs.start, ...ordered.map((s) => s.point), inputs.end]);
    const times = passageTimes(ride.direction, ride.targetTime, route.legs);
    const onboard = onboardDistances(ride.direction, route.legs);
    const detours = route.estimated ? new Map<string, number>() : await this.realDetours(inputs.start, inputs.end, ordered, route);
    const price = await this.estimate(ride, route.distanceM, inputs.stops.length + 1);

    const etas = new Map<string, Date>([
      [ride.driverId, ride.direction === 'to_campus' ? times[0]! : times.at(-1)!],
      ...ordered.map((s, i): [string, Date] => [s.userId, times[i + 1]!]),
    ]);
    const saved = await this.repo.transaction(async (tx) => {
      const current = await this.repo.ride(rideId, tx, true);
      if (!current) return false;
      const now = planInputs(current, await this.repo.members(rideId, tx));
      if (!now || planKey(now) !== planKey(inputs)) return false;
      await this.repo.savePlan(
        rideId,
        {
          geometry: route.geometry,
          distanceM: route.distanceM,
          durationS: route.durationS,
          estimated: route.estimated,
          totalCostCents: price?.totalCostCents ?? null,
          stops: [
            { userId: ride.driverId, order: 0, eta: ride.direction === 'to_campus' ? times[0]! : times.at(-1)! },
            ...ordered.map((s, i) => ({
              userId: s.userId,
              order: i + 1,
              eta: times[i + 1]!,
              onboardM: onboard[i] ?? null,
              detourS: detours.get(s.userId) ?? null,
            })),
          ],
          // Tracé estimé alors qu'un fournisseur existe : on retentera à la prochaine lecture.
          now: route.estimated && this.retryEstimated ? null : this.clock(),
        },
        tx,
      );
      return true;
    });
    if (saved) await this.noticeShiftedPassages(ride, members, etas).catch(() => undefined);
  }

  /**
   * Passager ajouté ou retiré sur un trajet confirmé vers le campus : chacun dont l'heure de
   * passage bouge (le conducteur part plus tôt, un passager est pris plus tôt) reçoit sa
   * nouvelle heure. Au retour, l'heure de départ du campus ne change pas.
   */
  private async noticeShiftedPassages(ride: RideInfo, members: readonly Member[], etas: ReadonlyMap<string, Date>) {
    if (!this.notifier || ride.status !== 'confirmed' || ride.direction !== 'to_campus') return;
    const previous = new Map(members.filter(isAccepted).map((m) => [m.userId, m.eta]));
    for (const shift of shiftedPassages(previous, etas)) {
      if (shift.eta <= this.clock()) continue;
      await this.notifier.notify([shift.userId], {
        type: 'pickup_time_changed',
        rideId: ride.id,
        time: parisTimeOf(shift.eta),
        earlier: shift.earlier,
        role: shift.userId === ride.driverId ? 'driver' : 'passenger',
      });
    }
  }

  /**
   * Détour réel de chaque passager (cahier §4) : durée du trajet avec lui moins durée sans lui,
   * sur de vrais itinéraires. Remplace l'estimation du matching une fois le trajet planifié.
   * Jusqu'à 4 passagers (un appel d'itinéraire par passager, plus le trajet direct pour un
   * seul), gardés en mémoire ; en cas d'échec, l'estimation reste.
   */
  private async realDetours(
    start: LatLon,
    end: LatLon,
    ordered: readonly { userId: string; point: LatLon }[],
    full: RouteResult,
  ): Promise<Map<string, number>> {
    const detours = new Map<string, number>();
    if (ordered.length === 0 || ordered.length > 4) return detours;
    try {
      for (const stop of ordered) {
        const others = ordered.filter((o) => o !== stop).map((o) => o.point);
        const without = await this.cachedRoute([start, ...others, end]);
        if (without.estimated) return new Map();
        detours.set(stop.userId, Math.max(0, Math.round(full.durationS - without.durationS)));
      }
    } catch {
      return new Map();
    }
    return detours;
  }

  /** Itinéraire gardé en mémoire par jeu de points (aperçus, détours réels). */
  private async cachedRoute(points: LatLon[]): Promise<RouteResult> {
    const key = points.map((p) => `${p.lat.toFixed(6)},${p.lon.toFixed(6)}`).join('|');
    const cached = this.previews.get(key);
    if (cached) return cached;
    const route = await this.routing.route(points);
    if (this.previews.size >= PREVIEW_CACHE_SIZE) this.previews.delete(this.previews.keys().next().value!);
    this.previews.set(key, route);
    return route;
  }

  /**
   * Parts au prorata de la distance à bord (cahier §5) pour les passagers donnés ; sans plan
   * (distance à bord inconnue), chacun compte pour tout le trajet.
   */
  async shares(
    ride: RideInfo,
    distanceM: number | null,
    passengers: readonly Pick<Member, 'userId' | 'onboardM'>[],
  ): Promise<Shares | null> {
    if (distanceM === null || ride.consumptionLPer100km === null) return null;
    const fuel = await this.settings.get('pricing.fuelPriceCentsPerLitre');
    const price = proRataPrice({
      consumptionLPer100km: ride.consumptionLPer100km,
      fuelPriceCentsPerLitre: fuel,
      commissionCentsPerPassenger: await this.settings.get('pricing.commissionCentsPerPassenger'),
      distanceM,
      onboardM: passengers.map((p) => p.onboardM),
    });
    return {
      totalCostCents: price.totalCostCents,
      commissionCents: price.commissionCents,
      byUser: new Map(passengers.map((p, i) => [p.userId, price.sharesCents[i]!])),
      driverReceivesCents: price.driverReceivesCents,
      consumptionLPer100km: ride.consumptionLPer100km,
      fuelPriceCentsPerLitre: fuel,
      distanceM,
      portions: price.portions.map((portion) => ({
        distanceM: portion.distanceM,
        riders: portion.riders.map((i) => passengers[i]!.userId),
      })),
    };
  }

  async estimate(ride: RideInfo, distanceM: number | null, persons: number): Promise<PriceEstimate | null> {
    if (distanceM === null || ride.consumptionLPer100km === null) return null;
    return estimatePrice({
      consumptionLPer100km: ride.consumptionLPer100km,
      distanceM,
      fuelPriceCentsPerLitre: await this.settings.get('pricing.fuelPriceCentsPerLitre'),
      commissionCentsPerPassenger: await this.settings.get('pricing.commissionCentsPerPassenger'),
      persons,
    });
  }

  /**
   * Prix maximal pour un passager (cahier §5, décision du 17/10/2026) : ce qu'il paierait s'il
   * était le seul passager présent. Son solde doit le couvrir pour accepter, et il est retenu au
   * départ ; le prix final, partagé entre les présents, ne le dépasse jamais. Avant le calcul de
   * l'itinéraire, distance estimée (ligne droite × facteur routier, plus son détour).
   */
  /** Distance de facturation : le tracé calculé, sinon l'estimation utilisée pour la retenue. */
  async billingDistance(rideId: string): Promise<number | null> {
    const ride = await this.repo.ride(rideId);
    if (!ride) return null;
    if (ride.distanceM !== null) return ride.distanceM;
    const members = (await this.repo.members(rideId)).filter(isAccepted);
    const home = members.find((m) => m.role === 'driver')?.home;
    if (!home) return null;
    const speed = ((await this.settings.get('matching.avgSpeedKmh')) * 1000) / 3600;
    const detours = members.filter((m) => m.role === 'passenger').reduce((sum, m) => sum + (m.detourS ?? 0) * speed, 0);
    return Math.round(distanceMeters(home, ride.campus) * (await this.settings.get('matching.roadFactor')) + detours);
  }

  /**
   * Prix indicatif d'un trajet pour une personne, affiché sur l'accueil et au choix d'une
   * voiture : ce que paie le passager (part + commission) ou ce que reçoit le conducteur. Trajet
   * planifié : le partage au prorata réel ; sinon une estimation au partage égal avec les
   * passagers prévus (et `joiningDetourS` : celui qui regarde, pas encore à bord). Conducteur
   * sans passager : null (rien à recevoir).
   */
  async quote(rideId: string, userId: string, joiningDetourS?: number): Promise<number | null> {
    const ride = await this.repo.ride(rideId);
    if (!ride || ride.consumptionLPer100km === null) return null;
    const members = await this.repo.members(rideId);
    const me = members.find((m) => m.userId === userId);
    const driver = me?.role === 'driver';
    const accepted = members.filter((m) => m.role === 'passenger' && isAccepted(m));
    if (joiningDetourS === undefined && ride.plannedAt && ride.distanceM !== null && accepted.length > 0) {
      const shares = await this.shares(ride, ride.distanceM, accepted);
      if (shares) {
        if (driver) return shares.driverReceivesCents;
        const mine = shares.byUser.get(userId);
        if (mine !== undefined) return mine + shares.commissionCents;
      }
    }
    const planned = members.filter(
      (m) => m.role === 'passenger' && (isAccepted(m) || m.status === 'proposed' || m.status === 'requested'),
    );
    const joining = joiningDetourS !== undefined && !planned.some((m) => m.userId === userId);
    const passengers = planned.length + (joining ? 1 : 0);
    if (passengers === 0) return null;
    let distanceM = ride.distanceM;
    if (distanceM === null || joining) {
      const home = members.find((m) => m.role === 'driver')?.home;
      if (distanceM === null && !home) return null;
      const speed = ((await this.settings.get('matching.avgSpeedKmh')) * 1000) / 3600;
      const base = distanceM ?? distanceMeters(home!, ride.campus) * (await this.settings.get('matching.roadFactor'));
      const detours = (distanceM === null ? planned.reduce((sum, m) => sum + (m.detourS ?? 0), 0) : 0) + (joining ? joiningDetourS : 0);
      distanceM = Math.round(base + detours * speed);
    }
    const estimate = await this.estimate(ride, distanceM, passengers + 1);
    if (!estimate) return null;
    return driver ? estimate.driverReceivesCents : estimate.passengerPaysCents;
  }

  /** Replan après le départ (passagers retirés faute de solde) : le tracé raccourcit. */
  async replanStarted(rideId: string): Promise<void> {
    await this.plan(rideId);
  }

  async maxPassengerPrice(rideId: string, passengerId: string, detourOverrideS?: number | null): Promise<number | null> {
    const ride = await this.repo.ride(rideId);
    if (!ride || ride.consumptionLPer100km === null) return null;
    const members = await this.repo.members(rideId);
    const driver = members.find((m) => m.role === 'driver');
    const me = members.find((m) => m.userId === passengerId);
    let distanceM = ride.distanceM;
    if (distanceM === null) {
      if (!driver?.home) return null;
      distanceM = distanceMeters(driver.home, ride.campus) * (await this.settings.get('matching.roadFactor'));
    }
    // Pas encore dans l'itinéraire calculé : son détour s'ajoute.
    if (detourOverrideS !== undefined || !me || me.stopOrder === null || ride.distanceM === null) {
      const speed = ((await this.settings.get('matching.avgSpeedKmh')) * 1000) / 3600;
      distanceM += (detourOverrideS ?? me?.detourS ?? 0) * speed;
    }
    const estimate = await this.estimate(ride, Math.round(distanceM), 2);
    return estimate?.passengerPaysCents ?? null;
  }

  /** Participant accepté d'un trajet confirmé, sinon 403 (ou 404 si le trajet n'existe pas). */
  private async access(userId: string, rideId: string): Promise<{ ride: RideInfo; members: Member[]; me: Member }> {
    const ride = await this.repo.ride(rideId);
    if (!ride) throw new AppError(404, 'not_found', 'Ressource introuvable');
    const members = await this.repo.members(rideId);
    // Un passager compté absent garde l'accès au trajet clôturé (litige, cahier §10).
    const me = members.find(
      (m) => m.userId === userId && (isAccepted(m) || (m.status === 'absent' && ride.status === 'completed')),
    );
    if (!me) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
    if (!VISIBLE_STATUSES.has(ride.status)) {
      throw new AppError(409, 'ride_not_confirmed', "Ce trajet n'est pas encore confirmé");
    }
    return { ride, members, me };
  }

  async get(userId: string, rideId: string): Promise<RideView> {
    let { ride, members, me } = await this.access(userId, rideId);
    // Plan figé une fois le trajet commencé : le prix retenu au départ en dépend.
    if (!ride.plannedAt && ride.status === 'confirmed') {
      await this.plan(rideId);
      ({ ride, members, me } = await this.access(userId, rideId));
    }
    const accepted = members.filter(isAccepted);
    const driver = accepted.find((m) => m.role === 'driver');
    const passengers = accepted
      .filter((m) => m.role === 'passenger')
      .sort((a, b) => (a.stopOrder ?? 99) - (b.stopOrder ?? 99) || a.userId.localeCompare(b.userId));
    // Nom de famille : entre conducteur et passager acceptés, et pour soi-même.
    const lastNameFor = (m: Member) =>
      m.userId === me.userId || me.role === 'driver' || m.role === 'driver' ? m.lastName : null;

    const campus: Omit<StopView, 'order'> = {
      kind: 'campus',
      userId: null,
      firstName: null,
      lastName: null,
      label: ride.campus.name,
      lat: ride.campus.lat,
      lon: ride.campus.lon,
      // Aller : arrivée à l'heure cible ; retour : départ à l'heure cible.
      eta: ride.targetTime,
      isMeetingPoint: false,
      approximate: false,
      pickedUp: false,
      presenceValidated: false,
      arrived: false,
      ended: false,
    };
    // Entre passagers, pas d'acceptation mutuelle (cahier §4, §14) : le domicile d'un autre
    // passager n'est montré qu'au secteur près ; son point de rendez-vous, lieu public, l'est.
    // Le passager n'a pas besoin du domicile du conducteur : son départ reste approximatif.
    const hidden: LatLon[] = [];
    const person = (m: Member, kind: 'driver' | 'passenger'): Omit<StopView, 'order'> | null => {
      const pickup = kind === 'driver' ? (m.home ? { point: m.home, label: m.homeLabel ?? '', isMeetingPoint: false } : null) : pickupOf(m);
      if (!pickup) return null;
      const masked = me.role === 'passenger' && m.userId !== me.userId && !pickup.isMeetingPoint;
      if (masked) hidden.push(pickup.point);
      const point = masked ? publicSector(sectorOf(pickup.point)) : pickup.point;
      return {
        kind,
        userId: m.userId,
        firstName: m.firstName,
        lastName: lastNameFor(m),
        label: masked ? '' : pickup.label,
        lat: point.lat,
        lon: point.lon,
        eta: m.eta,
        isMeetingPoint: pickup.isMeetingPoint,
        approximate: masked,
        pickedUp: m.status === 'picked_up',
        presenceValidated: m.presenceValidatedAt !== null,
        arrived: m.arrivedAt !== null,
        ended: m.endedAt !== null,
      };
    };
    const driverStop = driver ? person(driver, 'driver') : null;
    const middle = passengers.map((p) => person(p, 'passenger')).filter((s): s is Omit<StopView, 'order'> => s !== null);
    const sequence =
      ride.direction === 'to_campus' ? [driverStop, ...middle, campus] : [campus, ...middle, driverStop];
    const stops = sequence
      .filter((s): s is Omit<StopView, 'order'> => s !== null)
      .map((s, order) => ({ ...s, order }));

    const shares = await this.shares(ride, ride.distanceM, passengers);
    return {
      id: ride.id,
      day: ride.day,
      direction: ride.direction,
      time: ride.targetTime,
      status: ride.status,
      role: me.role,
      myStatus: me.status,
      seatsTotal: ride.seatsTotal,
      vehicle: ride.vehicle,
      distanceM: ride.distanceM,
      durationS: ride.durationS,
      routeEstimated: ride.routeEstimated,
      // Le tracé ne doit pas trahir un domicile masqué : on retire ses abords.
      route: (ride.plannedAt || ride.distanceM !== null ? await this.repo.routeGeometry(rideId) : []).filter(
        ([lat, lon]) => hidden.every((h) => distanceMeters(h, { lat, lon }) > SECTOR_SIZE_M),
      ),
      stops,
      price: shares ? priceView(shares, passengers.length + 1, me, passengers) : null,
    };
  }

  /**
   * Aperçu d'un trajet proposé (avant confirmation) : tracé du conducteur passant par les
   * personnes proposées ou acceptées, sans les abords de leurs domiciles ni de celui du
   * conducteur (seul mon point est exact). Calculé à la demande, gardé en mémoire.
   */
  async preview(userId: string, rideId: string): Promise<RidePreview> {
    const ride = await this.repo.ride(rideId);
    if (!ride) throw new AppError(404, 'not_found', 'Ressource introuvable');
    const members = (await this.repo.members(rideId)).filter((m) => PREVIEW_STATUSES.has(m.status));
    const me = members.find((m) => m.userId === userId);
    if (!me) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
    const driver = members.find((m) => m.role === 'driver');
    const campus = { name: ride.campus.name, lat: ride.campus.lat, lon: ride.campus.lon };
    const mine = me.role === 'driver' ? me.home : (pickupOf(me)?.point ?? null);
    if (!driver?.home) return { route: [], estimated: true, campus, me: mine };

    const stops = members
      .filter((m) => m.role === 'passenger')
      .flatMap((m) => {
        const pickup = pickupOf(m);
        return pickup ? [{ userId: m.userId, point: pickup.point }] : [];
      });
    const inputs =
      ride.direction === 'to_campus'
        ? { start: driver.home, end: campus as LatLon, stops }
        : { start: campus as LatLon, end: driver.home, stops };
    const key = planKey(inputs);
    let route = this.previews.get(key);
    if (!route) {
      const ordered = orderStops(inputs.start, inputs.end, inputs.stops);
      route = await this.routing.route([inputs.start, ...ordered.map((s) => s.point), inputs.end]);
      if (this.previews.size >= PREVIEW_CACHE_SIZE) this.previews.delete(this.previews.keys().next().value!);
      this.previews.set(key, route);
    }
    const hidden = members
      .filter((m) => m.userId !== userId)
      .flatMap((m) => {
        const point = m.role === 'driver' ? m.home : (pickupOf(m)?.isMeetingPoint ? null : m.home);
        return point ? [point] : [];
      });
    return {
      route: thin(route.geometry)
        .filter((p) => hidden.every((h) => distanceMeters(h, p) > SECTOR_SIZE_M))
        .map((p) => [p.lat, p.lon]),
      estimated: route.estimated,
      campus,
      me: mine,
    };
  }

  /** Historique : trajets terminés, 50 au plus. */
  history(userId: string): Promise<HistoryRow[]> {
    return this.repo.history(userId, 50);
  }

  async price(userId: string, rideId: string): Promise<PriceView | null> {
    return (await this.get(userId, rideId)).price;
  }

  /**
   * Point de rendez-vous du passager (cahier §14) : il remplace son adresse auprès du
   * conducteur. Proche du domicile (paramètre `rides.meetingPointMaxMeters`).
   */
  async setPickup(
    userId: string,
    rideId: string,
    input: { useMeetingPoint: boolean; label?: string | undefined; lat?: number | undefined; lon?: number | undefined },
  ): Promise<void> {
    const max = await this.settings.get('rides.meetingPointMaxMeters');
    // Sous le verrou du trajet : un départ simultané ne laisse pas passer la modification.
    await this.repo.transaction(async (tx) => {
      const ride = await this.repo.ride(rideId, tx, true);
      if (!ride) throw new AppError(404, 'not_found', 'Ressource introuvable');
      const me = (await this.repo.members(rideId, tx)).find((m) => m.userId === userId && isAccepted(m));
      if (!me || me.role !== 'passenger') throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
      if (LOCKED_STATUSES.has(ride.status)) throw new AppError(409, 'ride_locked', 'Ce trajet ne peut plus être modifié');

      let pickup: { label: string; point: LatLon } | null = null;
      if (input.useMeetingPoint) {
        const label = input.label?.trim();
        if (!label || input.lat === undefined || input.lon === undefined) {
          throw new AppError(400, 'validation_error', 'Indique le point de rendez-vous');
        }
        pickup = { label, point: { lat: input.lat, lon: input.lon } };
        if (!me.home || distanceMeters(me.home, pickup.point) > max) {
          throw new AppError(422, 'meeting_point_too_far', 'Choisis un point plus proche de chez toi');
        }
      }
      await this.repo.setPickup(rideId, userId, pickup, tx);
    });
    await this.onRideChanged(rideId);
  }
}

interface Shares {
  totalCostCents: number;
  commissionCents: number;
  byUser: Map<string, number>;
  driverReceivesCents: number;
  consumptionLPer100km: number;
  fuelPriceCentsPerLitre: number;
  distanceM: number;
  portions: { distanceM: number; riders: string[] }[];
}

function priceView(shares: Shares, persons: number, me: Member, members: readonly Member[] = []): PriceView {
  const driver = me.role === 'driver';
  const names = new Map(members.map((m) => [m.userId, m.firstName]));
  // Passager : sa part ; conducteur : ce qu'il reçoit (somme des parts).
  const mine = me.role === 'passenger' ? (shares.byUser.get(me.userId) ?? 0) : shares.driverReceivesCents;
  return {
    totalCostCents: shares.totalCostCents,
    persons,
    shareCents: mine,
    commissionCents: shares.commissionCents,
    passengerPaysCents: me.role === 'passenger' ? mine + shares.commissionCents : 0,
    driverReceivesCents: shares.driverReceivesCents,
    estimated: true,
    youPayCents: me.role === 'passenger' ? mine + shares.commissionCents : null,
    youReceiveCents: me.role === 'driver' ? shares.driverReceivesCents : null,
    myDistanceM: me.role === 'passenger' ? me.onboardM : null,
    breakdown: {
      consumptionLPer100km: shares.consumptionLPer100km,
      fuelPriceCentsPerLitre: shares.fuelPriceCentsPerLitre,
      distanceM: shares.distanceM,
      portions: shares.portions
        .filter((p) => driver || p.riders.includes(me.userId))
        .map((p) => ({ distanceM: p.distanceM, persons: p.riders.length + 1 })),
      shares: driver
        ? [...shares.byUser].map(([userId, shareCents]) => ({ userId, firstName: names.get(userId) ?? '', shareCents }))
        : [],
    },
  };
}

/** Départ, arrivée et arrêts (passagers acceptés) d'un trajet. */
function planInputs(ride: RideInfo, members: Member[]) {
  const driver = members.find((m) => m.role === 'driver');
  if (!driver?.home) return null;
  const stops = members
    .filter((m) => m.role === 'passenger' && isAccepted(m))
    .flatMap((m) => {
      const pickup = pickupOf(m);
      return pickup ? [{ userId: m.userId, point: pickup.point }] : [];
    });
  const campus = { lat: ride.campus.lat, lon: ride.campus.lon };
  return ride.direction === 'to_campus'
    ? { start: driver.home, end: campus, stops }
    : { start: campus, end: driver.home, stops };
}

/** Tracé allégé pour l'app : un point tous les 25 m au moins (extrémités gardées). */
function thin(points: readonly LatLon[], minM = 25): LatLon[] {
  if (points.length <= 2) return [...points];
  const kept: LatLon[] = [points[0]!];
  for (let i = 1; i < points.length - 1; i++) {
    if (distanceMeters(kept.at(-1)!, points[i]!) >= minM) kept.push(points[i]!);
  }
  kept.push(points.at(-1)!);
  return kept;
}
