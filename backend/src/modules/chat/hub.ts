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

  add(userId: string, socket: UserSocket): void {
    const set = this.sockets.get(userId) ?? new Set();
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
      for (const socket of this.sockets.get(userId) ?? []) socket.send(data);
    }
  }
}
