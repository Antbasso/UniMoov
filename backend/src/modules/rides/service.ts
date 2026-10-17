import { AppError } from '../../shared/errors.js';
import { distanceMeters, type LatLon, SECTOR_SIZE_M, sectorOf } from '../../shared/geo.js';
import { publicSector } from '../matching/service.js';
import type { RoutingProvider } from '../../shared/routing/routing-provider.js';
import { estimatePrice, type PriceEstimate } from '../pricing/domain.js';
import { parisDateOf } from '../../shared/time.js';
import type { SettingsService } from '../settings/service.js';
import { type Direction, orderStops, passageTimes, planKey } from './domain.js';
import { isAccepted, type Member, pickupOf, type RideInfo, type RidesRepo } from './repo.js';

const VISIBLE_STATUSES = new Set(['confirmed', 'in_progress', 'completed']);
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
  ) {}

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
    const inputs = planInputs(ride, await this.repo.members(rideId));
    if (!inputs) return;
    const ordered = orderStops(inputs.start, inputs.end, inputs.stops);
    const route = await this.routing.route([inputs.start, ...ordered.map((s) => s.point), inputs.end]);
    const times = passageTimes(ride.direction, ride.targetTime, route.legs);
    const price = await this.estimate(ride, route.distanceM, inputs.stops.length + 1);

    await this.repo.transaction(async (tx) => {
      const current = await this.repo.ride(rideId, tx, true);
      if (!current) return;
      const now = planInputs(current, await this.repo.members(rideId, tx));
      if (!now || planKey(now) !== planKey(inputs)) return;
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
            ...ordered.map((s, i) => ({ userId: s.userId, order: i + 1, eta: times[i + 1]! })),
          ],
          // Tracé estimé alors qu'un fournisseur existe : on retentera à la prochaine lecture.
          now: route.estimated && this.retryEstimated ? null : this.clock(),
        },
        tx,
      );
    });
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
    if (!ride.plannedAt) {
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
      pickedUp: false,
      presenceValidated: false,
      arrived: false,
      ended: false,
    };
    // Entre passagers, pas d'acceptation mutuelle (cahier §4, §14) : le domicile d'un autre
    // passager n'est montré qu'au secteur près ; son point de rendez-vous, lieu public, l'est.
    const hidden: LatLon[] = [];
    const person = (m: Member, kind: 'driver' | 'passenger'): Omit<StopView, 'order'> | null => {
      const pickup = kind === 'driver' ? (m.home ? { point: m.home, label: m.homeLabel ?? '', isMeetingPoint: false } : null) : pickupOf(m);
      if (!pickup) return null;
      const coPassengerHome = me.role === 'passenger' && kind === 'passenger' && m.userId !== me.userId && !pickup.isMeetingPoint;
      if (coPassengerHome) hidden.push(pickup.point);
      const point = coPassengerHome ? publicSector(sectorOf(pickup.point)) : pickup.point;
      return {
        kind,
        userId: m.userId,
        firstName: m.firstName,
        lastName: lastNameFor(m),
        label: coPassengerHome ? '' : pickup.label,
        lat: point.lat,
        lon: point.lon,
        eta: m.eta,
        isMeetingPoint: pickup.isMeetingPoint,
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

    const estimate = await this.estimate(ride, ride.distanceM, passengers.length + 1);
    return {
      id: ride.id,
      day: ride.day,
      direction: ride.direction,
      time: ride.targetTime,
      status: ride.status,
      role: me.role,
      myStatus: me.status,
      seatsTotal: ride.seatsTotal,
      distanceM: ride.distanceM,
      durationS: ride.durationS,
      routeEstimated: ride.routeEstimated,
      // Le tracé ne doit pas trahir un domicile masqué : on retire ses abords.
      route: (ride.plannedAt || ride.distanceM !== null ? await this.repo.routeGeometry(rideId) : []).filter(
        ([lat, lon]) => hidden.every((h) => distanceMeters(h, { lat, lon }) > SECTOR_SIZE_M),
      ),
      stops,
      price: estimate ? priceView(estimate, me.role) : null,
    };
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

function priceView(estimate: PriceEstimate, role: 'driver' | 'passenger'): PriceView {
  return {
    ...estimate,
    estimated: true,
    youPayCents: role === 'passenger' ? estimate.passengerPaysCents : null,
    youReceiveCents: role === 'driver' ? estimate.driverReceivesCents : null,
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
