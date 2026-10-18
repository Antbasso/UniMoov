import { AppError } from '../../shared/errors.js';
import type { GeocodingProvider } from '../../shared/geocoding/geocoding-provider.js';
import { GeocodingUnavailableError } from '../../shared/geocoding/geocoding-provider.js';
import { sectorOf } from '../../shared/geo.js';
import {
  isDiscoveryMode,
  isPausedOn,
  isRoleModeAllowed,
  nextOnboardingStep,
  type OnboardingState,
  type OnboardingStep,
  type Pause,
  parisDate,
  pauseProblem,
  type RoleMode,
  type StepStatus,
} from './domain.js';
import type { ProfileRepo } from './repo.js';
import type { MeResponse } from './schema.js';

const MAX_PAUSES = 20;

/** Retire les clés absentes du corps PATCH (exactOptionalPropertyTypes). */
function withoutUndefined<T extends object>(values: T): { [K in keyof T]?: Exclude<T[K], undefined> } {
  return Object.fromEntries(Object.entries(values).filter(([, v]) => v !== undefined)) as {
    [K in keyof T]?: Exclude<T[K], undefined>;
  };
}

const notFound = () => new AppError(404, 'not_found', 'Ressource introuvable');

export class ProfileService {
  constructor(
    private readonly repo: ProfileRepo,
    private readonly geocoding: GeocodingProvider,
    private readonly clock: () => Date,
    /** Adresse, véhicule, rôle ou pause modifiés : le matching recalcule (cahier §3). */
    private readonly onMatchingInputsChanged: (userId: string) => Promise<void> = () => Promise.resolve(),
  ) {}

  async getMe(userId: string): Promise<MeResponse> {
    const user = await this.repo.findUser(userId);
    // Compte supprimé entre-temps : le jeton n'ouvre plus rien.
    if (!user) throw new AppError(401, 'unauthorized', 'Connexion requise');
    const [vehicle, pauseList] = await Promise.all([this.repo.findVehicle(userId), this.repo.listPauses(userId)]);

    const steps = user.onboardingSteps as OnboardingState;
    const nextStep = nextOnboardingStep(steps);
    const hasHome = user.homeAddress !== null && user.homeLat !== null && user.homeLon !== null;

    return {
      id: user.id,
      universityEmail: user.universityEmail,
      firstName: user.firstName,
      lastName: user.lastName,
      photoUrl: user.photoUrl,
      campusId: user.campusId,
      home: hasHome
        ? { address: user.homeAddress!, lat: user.homeLat!, lon: user.homeLon!, sector: user.homeSector ?? '' }
        : null,
      roleMode: user.roleMode,
      defaultNavApp: user.defaultNavApp as MeResponse['defaultNavApp'],
      reliabilityScore: Number(user.reliabilityScore),
      vehicle: vehicle
        ? {
            consumptionLPer100km: Number(vehicle.consumptionLPer100km),
            defaultSeats: vehicle.defaultSeats,
            maxDetourMinutes: vehicle.maxDetourMinutes,
          }
        : null,
      onboarding: { steps, nextStep, completed: nextStep === null },
      discoveryMode: isDiscoveryMode({ hasHome, campusId: user.campusId }),
      pausedToday: isPausedOn(pauseList, parisDate(this.clock())),
    };
  }

  async updateNames(userId: string, values: { firstName?: string | undefined; lastName?: string | undefined }): Promise<MeResponse> {
    await this.repo.updateUser(userId, withoutUndefined(values));
    return this.getMe(userId);
  }

  /**
   * Adresses proposées pendant la saisie (cahier §1) : l'utilisateur choisit une adresse qui
   * existe. Seuls les libellés partent vers le client.
   */
  async suggestAddresses(query: string): Promise<{ label: string }[]> {
    try {
      return (await this.geocoding.suggest(query, 5)).map(({ label }) => ({ label }));
    } catch (error) {
      if (error instanceof GeocodingUnavailableError) {
        throw new AppError(503, 'geocoding_unavailable', 'Recherche d’adresse indisponible pour l’instant');
      }
      throw error;
    }
  }

  /** Géocode côté serveur et calcule le secteur : le client n'envoie que le texte. */
  async setAddress(userId: string, address: string): Promise<MeResponse> {
    let result;
    try {
      result = await this.geocoding.geocode(address);
    } catch (error) {
      if (error instanceof GeocodingUnavailableError) {
        throw new AppError(503, 'geocoding_unavailable', 'Recherche d’adresse indisponible pour l’instant');
      }
      throw error;
    }
    if (!result) throw new AppError(422, 'address_not_found', 'Adresse introuvable');
    await this.repo.updateHome(userId, { address: result.label, lat: result.lat, lon: result.lon, sector: sectorOf(result) });
    await this.onMatchingInputsChanged(userId);
    return this.getMe(userId);
  }

  async setVehicle(
    userId: string,
    vehicle: { consumptionLPer100km: number; defaultSeats: number; maxDetourMinutes: number },
  ): Promise<MeResponse> {
    await this.repo.upsertVehicle(userId, {
      // numeric(4,1) : une décimale, passée en texte pour éviter toute erreur d'arrondi.
      consumptionLPer100km: vehicle.consumptionLPer100km.toFixed(1),
      defaultSeats: vehicle.defaultSeats,
      maxDetourMinutes: vehicle.maxDetourMinutes,
    });
    await this.onMatchingInputsChanged(userId);
    return this.getMe(userId);
  }

  async removeVehicle(userId: string): Promise<void> {
    if (!(await this.repo.deleteVehicle(userId, 'always_passenger'))) throw notFound();
    await this.onMatchingInputsChanged(userId);
  }

  async setPreferences(
    userId: string,
    prefs: {
      roleMode?: RoleMode | undefined;
      defaultNavApp?: 'google_maps' | 'waze' | 'apple_maps' | null | undefined;
    },
  ): Promise<MeResponse> {
    if (prefs.roleMode && !isRoleModeAllowed(prefs.roleMode, Boolean(await this.repo.findVehicle(userId)))) {
      throw new AppError(409, 'vehicle_required', 'Déclare un véhicule pour conduire');
    }
    await this.repo.updateUser(userId, withoutUndefined(prefs));
    if (prefs.roleMode) await this.onMatchingInputsChanged(userId);
    return this.getMe(userId);
  }

  async setOnboardingStep(userId: string, step: OnboardingStep, status: StepStatus): Promise<MeResponse> {
    const steps = await this.repo.setOnboardingStep(userId, step, status);
    if (nextOnboardingStep(steps) === null) {
      await this.repo.updateUser(userId, { onboardingCompletedAt: this.clock() });
    }
    return this.getMe(userId);
  }

  listPauses(userId: string) {
    return this.repo.listPauses(userId);
  }

  async addPause(userId: string, pause: Pause) {
    const problem = pauseProblem(pause);
    if (problem) throw new AppError(400, 'invalid_pause', problem);
    if ((await this.repo.countPauses(userId)) >= MAX_PAUSES) {
      throw new AppError(409, 'too_many_pauses', 'Trop de pauses programmées');
    }
    const created = await this.repo.insertPause(userId, pause);
    await this.onMatchingInputsChanged(userId);
    return created;
  }

  async removePause(userId: string, pauseId: string): Promise<void> {
    if (!(await this.repo.deletePause(userId, pauseId))) throw notFound();
    await this.onMatchingInputsChanged(userId);
  }

  async getPublicProfile(userId: string) {
    const user = await this.repo.findPublicUser(userId);
    if (!user) throw notFound();
    return { ...user, reliabilityScore: Number(user.reliabilityScore) };
  }
}
