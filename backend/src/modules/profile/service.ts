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
      studyProgram: user.studyProgram,
      birthYear: user.birthYear,
      interests: user.interests,
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
            model: vehicle.model,
            color: vehicle.color,
          }
        : null,
      onboarding: { steps, nextStep, completed: nextStep === null },
      discoveryMode: isDiscoveryMode({ hasHome, campusId: user.campusId }),
      pausedToday: isPausedOn(pauseList, parisDate(this.clock())),
    };
  }

  async updateNames(
    userId: string,
    values: {
      firstName?: string | undefined;
      lastName?: string | undefined;
      studyProgram?: string | null | undefined;
      birthYear?: number | null | undefined;
      interests?: string[] | undefined;
    },
  ): Promise<MeResponse> {
    const clean = withoutUndefined(values);
    // Centres d'intérêt : sans doublon (casse ignorée), dans l'ordre saisi.
    if (clean.interests) {
      const seen = new Set<string>();
      clean.interests = clean.interests.filter((i) => !seen.has(i.toLowerCase()) && seen.add(i.toLowerCase()));
    }
    await this.repo.updateUser(userId, clean);
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
    vehicle: {
      consumptionLPer100km: number;
      defaultSeats: number;
      maxDetourMinutes: number;
      model?: string | null | undefined;
      color?: string | null | undefined;
    },
  ): Promise<MeResponse> {
    await this.repo.upsertVehicle(userId, {
      // numeric(4,1) : une décimale, passée en texte pour éviter toute erreur d'arrondi.
      consumptionLPer100km: vehicle.consumptionLPer100km.toFixed(1),
      defaultSeats: vehicle.defaultSeats,
      maxDetourMinutes: vehicle.maxDetourMinutes,
      model: vehicle.model ?? null,
      color: vehicle.color ?? null,
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

  /** Profil d'une personne croisée (même trajet ou conversation), sinon 404 comme un inconnu. */
  async getPublicProfile(viewerId: string, userId: string) {
    if (viewerId !== userId && !(await this.repo.related(viewerId, userId))) throw notFound();
    const user = await this.repo.findPublicUser(userId);
    if (!user) throw notFound();
    const { birthYear, ...rest } = user;
    return {
      ...rest,
      reliabilityScore: Number(user.reliabilityScore),
      // Âge approché à l'année : seule l'année de naissance est gardée.
      age: birthYear === null ? null : Number(parisDate(this.clock()).slice(0, 4)) - birthYear,
    };
  }

  /**
   * Photo de profil (JPEG ou PNG, 600 Ko au plus, contrôlée sur ses premiers octets) : gardée
   * en base, servie par `GET /users/{id}/photo` ; l'URL change à chaque photo (cache des apps).
   */
  async setPhoto(userId: string, contentType: string, data: Buffer): Promise<MeResponse> {
    const jpeg = data.length > 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff;
    const png = data.length > 8 && data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    if ((contentType === 'image/jpeg' && !jpeg) || (contentType === 'image/png' && !png) || (!jpeg && !png)) {
      throw new AppError(400, 'photo_invalid', 'Choisis une photo JPEG ou PNG');
    }
    await this.repo.setPhoto(userId, { contentType, data, url: `/api/v1/users/${userId}/photo?v=${this.clock().getTime()}` });
    return this.getMe(userId);
  }

  async removePhoto(userId: string): Promise<void> {
    await this.repo.setPhoto(userId, null);
  }

  async getPhoto(viewerId: string, userId: string): Promise<{ contentType: string; data: Buffer }> {
    if (viewerId !== userId && !(await this.repo.related(viewerId, userId))) throw notFound();
    const photo = await this.repo.photo(userId);
    if (!photo) throw notFound();
    return photo;
  }
}
