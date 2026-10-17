import { AppError } from '../../shared/errors.js';
import type { AccountRepo } from './repo.js';

export interface AccountDeps {
  repo: AccountRepo;
  /** Lève `invalid_password` si le mot de passe ne correspond pas. */
  checkPassword: (userId: string, password: string) => Promise<void>;
  /** Annulation d'un trajet accepté : les autres sont prévenus et relancés (cahier §8). */
  cancelRide: (userId: string, rideId: string) => Promise<unknown>;
  /** Refus d'une proposition encore ouverte. */
  declineRide: (userId: string, rideId: string) => Promise<void>;
  /** Ferme les connexions temps réel encore ouvertes. */
  disconnect: (userId: string) => void;
  clock: () => Date;
  log: (data: object, message: string) => void;
}

/** Droits d'accès, de portabilité et d'effacement (RGPD, docs/rgpd.md). */
export class AccountService {
  constructor(private readonly deps: AccountDeps) {}

  async export(userId: string): Promise<Record<string, unknown>> {
    return { exportedAt: this.deps.clock().toISOString(), ...(await this.deps.repo.export(userId)) };
  }

  /** Tâche de nuit : codes, sessions, créneaux et compteurs périmés effacés. */
  purgeExpired(): Promise<Record<string, number>> {
    return this.deps.repo.purgeExpired(this.deps.clock());
  }

  /**
   * Suppression définitive après confirmation par le mot de passe. Refusée pendant un trajet
   * en cours ou tant que le portefeuille n'est pas vide (l'argent appartient à la personne).
   */
  async delete(userId: string, password: string): Promise<void> {
    const { repo, clock } = this.deps;
    await this.deps.checkPassword(userId, password);
    if (await repo.hasRideInProgress(userId)) {
      throw new AppError(409, 'ride_in_progress', 'Termine ton trajet en cours avant de supprimer ton compte');
    }
    const wallet = await repo.walletCents(userId);
    if (wallet.balanceCents !== 0 || wallet.heldCents !== 0) {
      throw new AppError(409, 'wallet_not_empty', "Ton portefeuille n'est pas vide : récupère ton solde avant de supprimer ton compte");
    }
    // Les autres sont prévenus comme pour une annulation ordinaire et on leur cherche une place.
    for (const p of await repo.upcomingParticipations(userId, clock())) {
      const step = p.status === 'accepted' ? this.deps.cancelRide(userId, p.rideId) : this.deps.declineRide(userId, p.rideId);
      await step.catch((err: unknown) => this.deps.log({ err }, 'account deletion: ride release failed'));
    }
    await repo.anonymize(userId, clock());
    this.deps.disconnect(userId);
  }
}
