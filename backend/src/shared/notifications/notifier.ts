/**
 * Notifications aux utilisateurs (cahier §8, §11), derrière une interface : journal en v1,
 * push FCM au jalon M6. Les événements ne portent que des identifiants, jamais de texte libre.
 */
export type NotificationEvent =
  | { type: 'ride_cancelled'; rideId: string; by: 'driver' | 'passenger' }
  | { type: 'replacement_proposed'; rideId: string };

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
