import type { LatLon } from '../../shared/geo.js';

/** Connexion WebSocket d'un participant (sous-ensemble de `ws`). */
export interface LiveSocket {
  send(data: string): void;
  close(code?: number, reason?: string): void;
}

export interface LiveClient {
  userId: string;
  socket: LiveSocket;
  lastPositionAt: number;
}

export interface LivePosition extends LatLon {
  ts: Date;
  receivedAt: number;
  /** Faux après un déplacement impossible : la position ne valide alors aucune présence. */
  trusted: boolean;
}

/** Au-delà, une position n'est plus assez fraîche pour valider une présence. */
export const PRESENCE_FRESH_MS = 60_000;

/** Codes de fermeture (docs/api.md). */
export const WS_CLOSE = {
  unauthorized: 4401,
  forbidden: 4403,
  /** Remplacé par une connexion plus récente de la même personne. */
  replaced: 4408,
  notStarted: 4409,
  closed: 4410,
} as const;

/**
 * Salles en mémoire, une par trajet en cours (architecture §6) : connexions et dernière
 * position de chacun. Rien n'est gardé après la clôture.
 */
export class TrackingHub {
  private readonly rooms = new Map<string, Set<LiveClient>>();
  private readonly positions = new Map<string, Map<string, LivePosition>>();
  private readonly closedRides = new Set<string>();

  /** Un seul socket par personne et par trajet : le précédent est fermé (pas de diffusion multipliée). */
  join(rideId: string, client: LiveClient): void {
    const room = this.rooms.get(rideId) ?? new Set();
    for (const other of [...room]) {
      if (other.userId !== client.userId) continue;
      room.delete(other);
      other.socket.close(WS_CLOSE.replaced, 'replaced');
    }
    room.add(client);
    this.rooms.set(rideId, room);
  }

  leave(rideId: string, client: LiveClient): void {
    const room = this.rooms.get(rideId);
    room?.delete(client);
    if (room?.size === 0) this.rooms.delete(rideId);
  }

  clients(rideId: string): LiveClient[] {
    return [...(this.rooms.get(rideId) ?? [])];
  }

  send(rideId: string, message: object, to: (userId: string) => boolean = () => true): void {
    const data = JSON.stringify(message);
    for (const client of this.rooms.get(rideId) ?? []) {
      if (to(client.userId)) client.socket.send(data);
    }
  }

  setPosition(rideId: string, userId: string, position: LivePosition): void {
    const room = this.positions.get(rideId) ?? new Map<string, LivePosition>();
    room.set(userId, position);
    this.positions.set(rideId, room);
  }

  position(rideId: string, userId: string): LivePosition | undefined {
    return this.positions.get(rideId)?.get(userId);
  }

  /** Clôture : connexions fermées, positions oubliées (seule la trace réduite reste en base). */
  close(rideId: string): void {
    for (const client of this.rooms.get(rideId) ?? []) client.socket.close(WS_CLOSE.closed, 'ride_closed');
    this.rooms.delete(rideId);
    this.positions.delete(rideId);
    this.closedRides.add(rideId);
  }

  /** Trajet clôturé pendant la vie du processus (ses états de suivi peuvent être oubliés). */
  isClosed(rideId: string): boolean {
    return this.closedRides.has(rideId);
  }

  isOpen(rideId: string): boolean {
    return (this.rooms.get(rideId)?.size ?? 0) > 0;
  }
}
