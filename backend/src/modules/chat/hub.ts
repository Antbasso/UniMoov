/** Connexion WebSocket d'un utilisateur (sous-ensemble de `ws`). */
export interface UserSocket {
  send(data: string): void;
  close(code?: number, reason?: string): void;
}

/**
 * Sockets utilisateur `GET /ws/me` en mémoire (un utilisateur peut avoir plusieurs
 * appareils). Seuls les membres d'une conversation reçoivent ses messages.
 */
export class UserHub {
  private readonly sockets = new Map<string, Set<UserSocket>>();

  /** Au plus quelques appareils par personne : le plus ancien socket est fermé. */
  static readonly MAX_PER_USER = 5;

  add(userId: string, socket: UserSocket): void {
    const set = this.sockets.get(userId) ?? new Set();
    if (set.size >= UserHub.MAX_PER_USER) {
      const oldest = set.values().next().value!;
      set.delete(oldest);
      oldest.close(4408, 'too_many_sockets');
    }
    set.add(socket);
    this.sockets.set(userId, set);
  }

  remove(userId: string, socket: UserSocket): void {
    const set = this.sockets.get(userId);
    set?.delete(socket);
    if (set?.size === 0) this.sockets.delete(userId);
  }

  isOnline(userId: string): boolean {
    return (this.sockets.get(userId)?.size ?? 0) > 0;
  }

  send(userIds: readonly string[], message: object): void {
    const data = JSON.stringify(message);
    for (const userId of userIds) {
      for (const socket of this.sockets.get(userId) ?? []) {
        try {
          socket.send(data);
        } catch {
          // Socket en cours de fermeture : le message est enregistré, il sera relu.
        }
      }
    }
  }
}
