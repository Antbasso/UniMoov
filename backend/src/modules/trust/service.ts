import { AppError } from '../../shared/errors.js';
import type { MailProvider } from '../../shared/mail/mail-provider.js';
import type { SettingsService } from '../settings/service.js';
import {
  arbitrate,
  type Arbitration,
  cancelPenalty,
  cancelTier,
  type CancelTier,
  type DisputeReason,
  type ReliabilityKind,
  reliabilityScore,
} from './domain.js';
import type { DbOrTx, DisputeRow, MemberFacts, RideFacts, TrustRepo } from './repo.js';

const DAY_MS = 86_400_000;
/** A pris un engagement sur ce trajet (pas une simple proposition). */
const ENGAGED = new Set(['accepted', 'picked_up', 'absent', 'cancelled']);
const CONTESTABLE: Record<string, DisputeReason> = {
  cancel_early: 'cancellation_penalty',
  cancel_medium: 'cancellation_penalty',
  cancel_late: 'cancellation_penalty',
  no_show: 'marked_absent',
};

export interface DisputeView {
  id: string;
  rideId: string;
  reason: DisputeReason;
  level: number;
  decision: DisputeRow['decision'];
  explanation: Arbitration['explanation'];
  createdAt: Date;
  escalatedAt: Date | null;
}

const disputeView = (d: DisputeRow): DisputeView => ({
  id: d.id,
  rideId: d.rideId,
  reason: d.reason,
  level: d.level,
  decision: d.decision,
  explanation: d.resolution as Arbitration['explanation'],
  createdAt: d.createdAt,
  escalatedAt: d.escalatedAt,
});

/**
 * Confiance (cahier §7, §8, §10) : entrées du score, notes croisées, litiges et
 * signalements. Le score est recalculé à chaque entrée, depuis la fenêtre configurée.
 */
export class TrustService {
  constructor(
    private readonly repo: TrustRepo,
    private readonly settings: SettingsService,
    private readonly mail: MailProvider,
    private readonly clock: () => Date,
  ) {}

  private async since(): Promise<Date> {
    return new Date(this.clock().getTime() - (await this.settings.get('reliability.windowDays')) * DAY_MS);
  }

  async recompute(userId: string, db?: DbOrTx): Promise<number> {
    const since = await this.since();
    const score = reliabilityScore(await this.repo.entriesSince(userId, since, db), await this.repo.starsSince(userId, since, db), {
      prior: await this.settings.get('reliability.prior'),
      priorWeight: await this.settings.get('reliability.priorWeight'),
      ratingShare: await this.settings.get('reliability.ratingShare'),
    });
    await this.repo.setScore(userId, score, db);
    return score;
  }

  /** Palier de pénalité si l'annulation avait lieu maintenant (affiché avant de confirmer). */
  async cancellationTier(rideTime: Date): Promise<CancelTier> {
    return cancelTier(this.clock(), rideTime, await this.settings.get('reliability.penalties'));
  }

  /** Annulation après acceptation (cahier §8) : pénalité dégressive selon le délai. */
  async penalizeCancellation(userId: string, rideId: string, rideTime: Date, db: DbOrTx): Promise<CancelTier> {
    const params = await this.settings.get('reliability.penalties');
    const now = this.clock();
    const tier = cancelTier(now, rideTime, params);
    const { kind, weight } = cancelPenalty(tier, params);
    if (await this.repo.insertEvent(userId, rideId, kind, weight, now, db)) await this.recompute(userId, db);
    return tier;
  }

  /** Clôture : trajet mené à bien pour le conducteur et les présents, absence pour les autres (§9). */
  async onRideFinished(rideId: string, outcome: { completed: string[]; noShow: string[] }, db: DbOrTx): Promise<void> {
    const { noShow } = await this.settings.get('reliability.penalties');
    const now = this.clock();
    for (const userId of outcome.completed) {
      if (await this.repo.insertEvent(userId, rideId, 'completed', 1, now, db)) await this.recompute(userId, db);
    }
    for (const userId of outcome.noShow) {
      if (await this.repo.insertEvent(userId, rideId, 'no_show', noShow, now, db)) await this.recompute(userId, db);
    }
  }

  private async completedRide(rideId: string): Promise<{ ride: RideFacts; members: MemberFacts[]; closesAt: Date }> {
    const ride = await this.repo.ride(rideId);
    if (!ride) throw new AppError(404, 'not_found', 'Ressource introuvable');
    const members = await this.repo.members(rideId);
    const days = await this.settings.get('ratings.windowDays');
    const closesAt = new Date((ride.endedAt ?? ride.targetTime).getTime() + days * DAY_MS);
    return { ride, members, closesAt };
  }

  /** Qui peut noter qui (cahier §7) : conducteur ↔ passagers présents, jamais entre passagers. */
  private rateable(ride: RideFacts, members: MemberFacts[], raterId: string): MemberFacts[] {
    const present = (m: MemberFacts) => m.role === 'passenger' && m.presenceValidatedAt !== null;
    const me = members.find((m) => m.userId === raterId);
    if (!me) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
    if (me.role === 'driver' && ride.driverId === raterId) return members.filter(present);
    if (present(me)) return members.filter((m) => m.role === 'driver' && m.userId === ride.driverId);
    throw new AppError(403, 'forbidden', 'Seules les personnes présentes notent ce trajet');
  }

  async ratings(userId: string, rideId: string) {
    const { ride, members, closesAt } = await this.completedRide(rideId);
    if (ride.status !== 'completed') throw new AppError(409, 'ride_not_completed', "Ce trajet n'est pas terminé");
    const people = this.rateable(ride, members, userId);
    const given = await this.repo.ratingsBy(rideId, userId);
    return {
      open: this.clock() < closesAt,
      closesAt,
      people: people.map((m) => ({
        userId: m.userId,
        firstName: m.firstName,
        photoUrl: m.photoUrl,
        role: m.role,
        stars: given.get(m.userId) ?? null,
      })),
    };
  }

  /** Note optionnelle de 1 à 5 étoiles, une fois par personne et par trajet. */
  async rate(raterId: string, rideId: string, ratedId: string, stars: number): Promise<void> {
    const { ride, members, closesAt } = await this.completedRide(rideId);
    if (ride.status !== 'completed') throw new AppError(409, 'ride_not_completed', "Ce trajet n'est pas terminé");
    if (!this.rateable(ride, members, raterId).some((m) => m.userId === ratedId)) {
      throw new AppError(409, 'not_rateable', 'Tu ne peux pas noter cette personne pour ce trajet');
    }
    if (this.clock() >= closesAt) throw new AppError(409, 'rating_closed', 'La notation de ce trajet est fermée');
    await this.repo.transaction(async (tx) => {
      if (!(await this.repo.insertRating(rideId, raterId, ratedId, stars, this.clock(), tx))) {
        throw new AppError(409, 'already_rated', 'Tu as déjà noté cette personne');
      }
      await this.recompute(ratedId, tx);
    });
  }

  /** Score et ce qui l'explique, sur la fenêtre configurée ; les pénalités récentes sont contestables. */
  async reliability(userId: string) {
    const since = await this.since();
    const entries = await this.repo.entriesSince(userId, since);
    const stars = await this.repo.starsSince(userId, since);
    const disputeDays = await this.settings.get('disputes.windowDays');
    const now = this.clock().getTime();
    const count = (kind: string) => entries.filter((e) => e.kind === kind).length;
    const events = await this.repo.recentEvents(userId, since, 20);
    return {
      score: await this.repo.score(userId),
      windowDays: await this.settings.get('reliability.windowDays'),
      completedRides: count('completed'),
      cancellations: { early: count('cancel_early'), medium: count('cancel_medium'), late: count('cancel_late') },
      noShows: count('no_show'),
      ratingsCount: stars.length,
      averageStars: stars.length > 0 ? Math.round((stars.reduce((a, b) => a + b, 0) / stars.length) * 10) / 10 : null,
      events: events.map((e) => ({
        id: e.id,
        // Les trajets menés à bien ne sont pas listés (requête du dépôt).
        kind: e.kind as Exclude<ReliabilityKind, 'completed'>,
        rideId: e.rideId,
        day: e.rideDay,
        createdAt: e.createdAt,
        disputeReason:
          e.rideId && CONTESTABLE[e.kind] && now - e.createdAt.getTime() <= disputeDays * DAY_MS ? CONTESTABLE[e.kind]! : null,
      })),
    };
  }

  /**
   * Litige (cahier §10). Niveau 1 : tranché sur les horodatages du serveur quand ils
   * suffisent ; sinon, ou si la personne conteste la décision, niveau 2 : l'équipe.
   */
  async openDispute(userId: string, rideId: string, reason: DisputeReason, message: string | null): Promise<DisputeView> {
    const ride = await this.repo.ride(rideId);
    if (!ride) throw new AppError(404, 'not_found', 'Ressource introuvable');
    const me = (await this.repo.members(rideId)).find((m) => m.userId === userId);
    if (!me || !ENGAGED.has(me.status)) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
    const days = await this.settings.get('disputes.windowDays');
    if (this.clock().getTime() > ride.targetTime.getTime() + days * DAY_MS) {
      throw new AppError(409, 'dispute_closed', 'Le délai pour signaler un problème sur ce trajet est passé');
    }
    if (reason === 'cancellation_penalty' ? me.status !== 'cancelled' : reason !== 'other' && ride.status !== 'completed') {
      throw new AppError(409, 'dispute_not_applicable', 'Ce motif ne correspond pas à ce trajet');
    }

    const params = await this.settings.get('reliability.penalties');
    const now = this.clock();
    const view = await this.repo.transaction(async (tx) => {
      const result = arbitrate(
        reason,
        { rideTime: ride.targetTime, participant: me, penalties: await this.repo.entriesForRide(userId, rideId, tx) },
        params,
      );
      const row = await this.repo.insertDispute(
        {
          rideId,
          openedBy: userId,
          reason,
          message,
          level: result.decision === 'escalated' ? 2 : 1,
          decision: result.decision,
          resolution: result.explanation,
          at: now,
        },
        tx,
      );
      if (!row) throw new AppError(409, 'dispute_exists', 'Tu as déjà signalé ce problème pour ce trajet');
      if (result.correction < 0) {
        await this.repo.insertEvent(userId, rideId, 'correction', result.correction, now, tx);
        await this.recompute(userId, tx);
      }
      return disputeView(row);
    });
    if (view.level === 2) await this.mailSupport(view, userId, message);
    return view;
  }

  /** Désaccord avec la décision automatique : transmis à l'équipe (idempotent). */
  async escalate(userId: string, disputeId: string, message: string | null): Promise<DisputeView> {
    const dispute = await this.repo.dispute(disputeId);
    if (!dispute || dispute.openedBy !== userId) throw new AppError(404, 'not_found', 'Ressource introuvable');
    if (await this.repo.escalate(disputeId, message, this.clock())) {
      const view = disputeView((await this.repo.dispute(disputeId))!);
      await this.mailSupport(view, userId, message);
      return view;
    }
    return disputeView(dispute);
  }

  async disputes(userId: string, rideId: string): Promise<DisputeView[]> {
    return (await this.repo.disputesFor(rideId, userId)).map(disputeView);
  }

  /** Signalement d'une personne croisée sur un trajet (proposé ou confirmé), transmis à l'équipe. */
  async report(userId: string, targetUserId: string, reason: string, message: string | null): Promise<{ id: string }> {
    if (targetUserId === userId) throw new AppError(400, 'validation_error', 'Requête invalide');
    // Même réponse qu'une personne inexistante : on ne révèle pas qui utilise l'app.
    if (!(await this.repo.sharedRide(userId, targetUserId))) throw new AppError(404, 'not_found', 'Ressource introuvable');
    const limit = await this.settings.get('reports.dailyLimit');
    if ((await this.repo.reportsSince(userId, new Date(this.clock().getTime() - DAY_MS))) >= limit) {
      throw new AppError(429, 'report_limit', 'Tu as atteint le nombre de signalements du jour');
    }
    const id = await this.repo.insertReport({ reporterId: userId, targetUserId, reason, message, at: this.clock() });
    const reporter = await this.repo.contact(userId);
    await this.mail.send({
      to: await this.settings.get('support.email'),
      subject: `Signalement ${id}`,
      text: [
        `Signalement : ${id}`,
        `Motif : ${reason}`,
        `Personne signalée (identifiant) : ${targetUserId}`,
        `Par : ${reporter?.firstName ?? ''} <${reporter?.email ?? ''}>`,
        '',
        message ?? '(sans message)',
      ].join('\n'),
    });
    return { id };
  }

  private async mailSupport(view: DisputeView, userId: string, message: string | null): Promise<void> {
    const contact = await this.repo.contact(userId);
    await this.mail.send({
      to: await this.settings.get('support.email'),
      subject: `Litige ${view.id} (niveau 2)`,
      text: [
        `Litige : ${view.id}`,
        `Trajet : ${view.rideId}`,
        `Motif : ${view.reason}`,
        `Décision automatique : ${view.decision} (${view.explanation})`,
        `Répondre à : ${contact?.firstName ?? ''} <${contact?.email ?? ''}>`,
        '',
        message ?? '(sans message)',
      ].join('\n'),
    });
  }
}
