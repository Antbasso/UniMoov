import type { NotificationEvent, Notifier } from '../../shared/notifications/notifier.js';
import type { PushMessage, PushProvider } from '../../shared/push/push-provider.js';
import type { SettingsService } from '../settings/service.js';
import { type Category, CATEGORIES, type NotificationsRepo } from './repo.js';

/** Catégorie de préférence de chaque événement (cahier §11 : couper le chat, garder les rappels). */
export function categoryOf(event: NotificationEvent): Category {
  switch (event.type) {
    case 'replacement_proposed':
    case 'proposals_ready':
    case 'ride_requested':
    case 'request_answered':
      return 'match';
    case 'ride_cancelled':
    case 'payment_required':
    case 'passenger_left':
      return 'ride_update';
    case 'ride_reminder':
      return 'ride_reminder';
    case 'chat_message':
      return 'chat';
  }
}

/**
 * Texte du push, en français, sans donnée sensible : ni adresse, ni contenu de message (il
 * s'afficherait sur un écran verrouillé), au plus le prénom de l'auteur d'un message.
 */
export function pushMessage(event: NotificationEvent): PushMessage {
  switch (event.type) {
    case 'ride_cancelled':
      return {
        title: 'Trajet modifié',
        body: event.by === 'driver' ? 'Ton conducteur a annulé. On te cherche une autre voiture.' : 'Un passager a annulé sa place.',
        data: { type: event.type, rideId: event.rideId },
      };
    case 'replacement_proposed':
      return { title: 'Nouvelle proposition', body: 'Une place se libère pour toi. Réponds vite.', data: { type: event.type, rideId: event.rideId } };
    case 'payment_required':
      return {
        title: 'Solde insuffisant',
        body: 'Ton solde ne couvrait pas le trajet : ta place est annulée. Recharge ton portefeuille.',
        data: { type: event.type, rideId: event.rideId },
      };
    case 'passenger_left':
      return {
        title: 'Passager descendu avant l’arrivée',
        body: 'Un passager a terminé son trajet avant l’arrivée : sa part ne te sera pas versée.',
        data: { type: event.type, rideId: event.rideId },
      };
    case 'ride_requested':
      return { title: 'Demande de place', body: 'Un passager demande à monter avec toi. Réponds-lui.', data: { type: event.type, rideId: event.rideId } };
    case 'request_answered':
      return event.approved
        ? { title: 'Place acceptée', body: 'Ton conducteur a accepté ta demande.', data: { type: event.type, rideId: event.rideId } }
        : { title: 'Demande refusée', body: 'Le conducteur ne peut pas te prendre. On te cherche une autre voiture.', data: { type: event.type, rideId: event.rideId } };
    case 'proposals_ready':
      return { title: 'Ta semaine est prête', body: 'Tes propositions de trajets sont arrivées.', data: { type: event.type, week: event.week } };
    case 'ride_reminder':
      return {
        title: 'Départ bientôt',
        body: `Ton trajet part dans ${event.minutes} min.`,
        data: { type: event.type, rideId: event.rideId },
      };
    case 'chat_message':
      return {
        title: event.senderFirstName ? `Message de ${event.senderFirstName}` : 'Nouveau message',
        body: 'Ouvre Uni-Moov pour le lire.',
        data: { type: event.type, conversationId: event.conversationId },
      };
  }
}

/** Notifications push (cahier §11) : appareils, préférences par catégorie, rappel avant le départ. */
export class NotificationService implements Notifier {
  constructor(
    private readonly repo: NotificationsRepo,
    private readonly push: PushProvider,
    private readonly settings: SettingsService,
    private readonly clock: () => Date,
  ) {}

  async notify(userIds: readonly string[], event: NotificationEvent): Promise<void> {
    const tokens = await this.repo.tokensFor([...new Set(userIds)], categoryOf(event));
    if (tokens.length === 0) return;
    const { invalidTokens } = await this.push.send(tokens, pushMessage(event));
    await this.repo.deleteTokens(invalidTokens);
  }

  async registerDevice(userId: string, platform: 'android' | 'ios', token: string): Promise<void> {
    await this.repo.upsertDevice(userId, platform, token, this.clock());
  }

  async unregisterDevice(userId: string, token: string): Promise<void> {
    await this.repo.deleteDevice(userId, token);
  }

  async preferences(userId: string) {
    return this.toView(await this.repo.preferences(userId));
  }

  async setPreferences(userId: string, prefs: { [K in 'match' | 'rideUpdate' | 'rideReminder' | 'chat']?: boolean | undefined }) {
    const keys: Record<string, Category> = { match: 'match', rideUpdate: 'ride_update', rideReminder: 'ride_reminder', chat: 'chat' };
    for (const [key, value] of Object.entries(prefs)) {
      if (value !== undefined && keys[key]) await this.repo.setPreference(userId, keys[key], value);
    }
    return this.preferences(userId);
  }

  private toView(prefs: Record<Category, boolean>) {
    return { match: prefs.match, rideUpdate: prefs.ride_update, rideReminder: prefs.ride_reminder, chat: prefs.chat };
  }

  /** Après la génération du vendredi : « ta semaine est prête » à ceux qui ont des propositions. */
  async notifyProposalsReady(week: string, fromDay: string, toDay: string): Promise<number> {
    const users = await this.repo.usersWithProposals(fromDay, toDay);
    await this.notify(users, { type: 'proposals_ready', week });
    return users.length;
  }

  /** Tâche toutes les 5 minutes : rappel aux participants d'un trajet qui part bientôt (§11). */
  async sendReminders(): Promise<number> {
    const minutes = await this.settings.get('notifications.reminderMinutes');
    const now = this.clock();
    const due = await this.repo.dueReminders(now, new Date(now.getTime() + minutes * 60_000));
    let sent = 0;
    for (const r of due) {
      if (!(await this.repo.markReminded(r.rideId, r.userId, now))) continue;
      const left = Math.max(1, Math.round((r.departure.getTime() - now.getTime()) / 60_000));
      try {
        await this.notify([r.userId], { type: 'ride_reminder', rideId: r.rideId, minutes: left });
        sent++;
      } catch {
        // Envoi raté : la marque est retirée, la tâche suivante (5 min) réessaie.
        await this.repo.unmarkReminded(r.rideId, r.userId);
      }
    }
    return sent;
  }
}

export { CATEGORIES };
