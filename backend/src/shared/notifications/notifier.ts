/**
 * Notifications aux utilisateurs (cahier §8, §11), derrière une interface : push (FCM) avec
 * préférences par catégorie (`NotificationService`). Les événements ne portent jamais le
 * texte d'un message (un écran verrouillé ne l'affiche pas), au plus le prénom de l'auteur.
 */
export type NotificationEvent =
  | { type: 'ride_cancelled'; rideId: string; by: 'driver' | 'passenger' }
  | { type: 'replacement_proposed'; rideId: string }
  | { type: 'ride_requested'; rideId: string }
  | { type: 'request_answered'; rideId: string; approved: boolean }
  | { type: 'proposals_ready'; week: string }
  | { type: 'ride_reminder'; rideId: string; minutes: number }
  | { type: 'chat_message'; conversationId: string; senderFirstName: string };

export interface Notifier {
  notify(userIds: readonly string[], event: NotificationEvent): Promise<void>;
}

/** Journal sans donnée personnelle : type d'événement et nombre de destinataires. */
export class LogNotifier implements Notifier {
  constructor(private readonly log: (data: object, message: string) => void) {}

  notify(userIds: readonly string[], event: NotificationEvent): Promise<void> {
    this.log({ event: event.type, recipients: userIds.length }, 'notification');
    return Promise.resolve();
  }
}

/** Pour les tests : garde les notifications envoyées. */
export class MemoryNotifier implements Notifier {
  readonly sent: { userIds: string[]; event: NotificationEvent }[] = [];

  notify(userIds: readonly string[], event: NotificationEvent): Promise<void> {
    this.sent.push({ userIds: [...userIds], event });
    return Promise.resolve();
  }
}
