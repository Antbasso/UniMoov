import { AppError } from '../../shared/errors.js';
import type { Notifier } from '../../shared/notifications/notifier.js';
import type { SettingsService } from '../settings/service.js';
import type { UserHub } from './hub.js';
import type { ChatRepo, ConversationKind, ConversationRow, DbOrTx, MessageRow } from './repo.js';

const DAY_MS = 86_400_000;

export interface MessageView {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  createdAt: Date;
}

export interface ConversationView {
  id: string;
  kind: ConversationKind;
  title: string | null;
  rideId: string | null;
  /** Chat de trajet : jour et sens, pour le distinguer des autres. */
  ride: { day: string; direction: 'to_campus' | 'from_campus' } | null;
  /** Lecture seule : chat de trajet archivé. */
  archived: boolean;
  /** Prénom et photo seulement : le nom de famille reste entre conducteur et passagers (§4). */
  members: { userId: string; firstName: string; photoUrl: string | null }[];
  unread: number;
  lastMessage: MessageView | null;
}

const messageView = (m: MessageRow): MessageView => ({
  id: m.id,
  conversationId: m.conversationId,
  senderId: m.senderId,
  body: m.body,
  createdAt: m.createdAt,
});

/**
 * Messagerie (cahier §6) : privé, groupe, chat de trajet lié au cycle de vie du trajet.
 * On n'écrit qu'aux personnes croisées sur un trajet ; seuls les membres lisent.
 */
export class ChatService {
  constructor(
    private readonly repo: ChatRepo,
    private readonly hub: UserHub,
    private readonly settings: SettingsService,
    private readonly notifier: Notifier,
    private readonly clock: () => Date,
  ) {}

  private archived(c: ConversationRow): boolean {
    return c.archivedAt !== null && c.archivedAt <= this.clock();
  }

  private async view(c: ConversationRow & { unread?: number; lastMessage?: MessageRow | null }): Promise<ConversationView> {
    return {
      id: c.id,
      kind: c.kind,
      title: c.title,
      rideId: c.rideId,
      ride: c.kind === 'ride' && c.rideId ? await this.repo.rideInfo(c.rideId) : null,
      archived: this.archived(c),
      members: (await this.repo.members(c.id)).map(({ userId, firstName, photoUrl }) => ({ userId, firstName, photoUrl })),
      unread: c.unread ?? 0,
      lastMessage: c.lastMessage ? messageView(c.lastMessage) : null,
    };
  }

  /** Membre, sinon 404 : on ne révèle pas l'existence d'une conversation. */
  private async member(userId: string, conversationId: string): Promise<ConversationRow> {
    const c = await this.repo.conversation(conversationId);
    if (!c || !(await this.repo.isMember(conversationId, userId))) throw new AppError(404, 'not_found', 'Ressource introuvable');
    return c;
  }

  async list(userId: string): Promise<ConversationView[]> {
    const rows = await this.repo.listFor(userId);
    return Promise.all(rows.map((c) => this.view(c)));
  }

  async get(userId: string, conversationId: string): Promise<ConversationView> {
    return this.view(await this.member(userId, conversationId));
  }

  /** Chat d'un trajet dont je suis membre (404 sinon, ou s'il n'existe pas encore). */
  async forRide(userId: string, rideId: string): Promise<ConversationView> {
    const c = await this.repo.byRide(rideId);
    if (!c) throw new AppError(404, 'not_found', 'Ressource introuvable');
    return this.view(await this.member(userId, c.id));
  }

  async contacts(userId: string) {
    return this.repo.contacts(userId);
  }

  /** Privé (réutilisé s'il existe) ou groupe, seulement avec des personnes croisées sur un trajet. */
  async create(userId: string, input: { kind: 'direct' | 'group'; memberIds: string[]; title?: string | undefined }): Promise<ConversationView> {
    const others = [...new Set(input.memberIds.filter((id) => id !== userId))];
    if (others.length === 0) throw new AppError(400, 'validation_error', 'Requête invalide');
    if (!(await this.repo.sharedRideWithAll(userId, others))) {
      throw new AppError(403, 'not_a_contact', "Tu ne peux écrire qu'aux personnes croisées sur un trajet");
    }
    const now = this.clock();
    if (input.kind === 'direct') {
      if (others.length !== 1) throw new AppError(400, 'validation_error', 'Requête invalide');
      const key = [userId, others[0]!].sort().join('|');
      return this.get(userId, await this.repo.upsertDirect(key, [userId, ...others], userId, now));
    }
    const title = input.title?.trim();
    if (!title) throw new AppError(400, 'validation_error', 'Donne un nom au groupe');
    if (others.length + 1 > (await this.settings.get('chat.maxGroupMembers'))) {
      throw new AppError(422, 'group_too_large', 'Ce groupe compte trop de personnes');
    }
    const id = await this.repo.create({ kind: 'group', title, createdBy: userId, at: now }, [userId, ...others]);
    return this.get(userId, id);
  }

  /** Quitter un groupe ; un groupe vide est supprimé avec ses messages. */
  async leave(userId: string, conversationId: string): Promise<void> {
    const c = await this.member(userId, conversationId);
    if (c.kind !== 'group') throw new AppError(409, 'cannot_leave', 'Seul un groupe peut être quitté');
    await this.repo.removeMembers(conversationId, [userId]);
    if ((await this.repo.members(conversationId)).length === 0) await this.repo.setRetention(conversationId, this.clock(), this.clock());
  }

  async messages(userId: string, conversationId: string, before: { at: Date; id: string | null } | null, limit: number): Promise<MessageView[]> {
    await this.member(userId, conversationId);
    return (await this.repo.messages(conversationId, before, limit)).map(messageView);
  }

  async markRead(userId: string, conversationId: string): Promise<void> {
    await this.member(userId, conversationId);
    await this.repo.markRead(conversationId, userId, this.clock());
  }

  /** Message envoyé en direct aux membres connectés, et en push aux autres (préférence « chat »). */
  async send(userId: string, conversationId: string, body: string): Promise<MessageView> {
    const text = body.trim();
    if (!text) throw new AppError(400, 'validation_error', 'Requête invalide');
    const message = await this.repo.transaction(async (tx) => {
      // Sous le verrou : un archivage simultané n'accepte pas de nouveau message.
      const c = await this.repo.conversation(conversationId, tx, true);
      if (!c || !(await this.repo.isMember(conversationId, userId, tx))) throw new AppError(404, 'not_found', 'Ressource introuvable');
      if (this.archived(c)) throw new AppError(409, 'conversation_archived', 'Cette conversation est archivée');
      return this.repo.insertMessage(conversationId, userId, text, this.clock(), tx);
    });
    const members = await this.repo.members(conversationId);
    const view = messageView(message);
    this.hub.send(members.map((m) => m.userId), { type: 'message', message: view });
    const sender = members.find((m) => m.userId === userId);
    const offline = members.filter((m) => m.userId !== userId && !this.hub.isOnline(m.userId)).map((m) => m.userId);
    if (offline.length > 0) {
      // En tâche de fond : un FCM lent ne retarde pas la réponse (sinon renvoi et doublon).
      void this.notifier
        .notify(offline, { type: 'chat_message', conversationId, senderFirstName: sender?.firstName ?? '' })
        .catch(() => undefined);
    }
    return view;
  }

  /**
   * Chat de trajet (cahier §6) : créé à la confirmation, membres = personnes acceptées.
   * Fin ou annulation du trajet : lecture seule après `chat.rideArchiveDays`, puis supprimé
   * `chat.rideDeleteDays` plus tard. Idempotent, appelé à chaque changement du trajet.
   */
  async syncRideChat(rideId: string): Promise<void> {
    // Sous le verrou du trajet : deux acceptations simultanées ne créent pas deux chats et
    // une lecture périmée ne retire pas un membre ajouté entre-temps.
    await this.repo.transaction(async (tx) => {
      await this.repo.lockRide(rideId, tx);
      const ride = await this.repo.rideMembers(rideId, tx);
      if (!ride) return;
      const existing = await this.repo.byRide(rideId, tx);
      const live = ride.status === 'confirmed' || ride.status === 'in_progress';
      const now = this.clock();
      if (!existing) {
        if (!live || ride.members.length < 2) return;
        await this.repo.create({ kind: 'ride', title: null, rideId, createdBy: null, at: now }, ride.members, tx);
        return;
      }
      if (live || ride.status === 'proposed') {
        const current = new Set((await this.repo.members(existing.id, tx)).map((m) => m.userId));
        const wanted = new Set(ride.members);
        await this.repo.addMembers(existing.id, [...wanted].filter((u) => !current.has(u)), now, tx);
        await this.repo.removeMembers(existing.id, [...current].filter((u) => !wanted.has(u)), tx);
        return;
      }
      if (existing.deleteAfter === null) await this.scheduleRetention(existing.id, ride.endedAt ?? now, tx);
    });
  }

  private async scheduleRetention(conversationId: string, from: Date, db?: DbOrTx): Promise<void> {
    const archiveAt = new Date(from.getTime() + (await this.settings.get('chat.rideArchiveDays')) * DAY_MS);
    const deleteAt = new Date(archiveAt.getTime() + (await this.settings.get('chat.rideDeleteDays')) * DAY_MS);
    await this.repo.setRetention(conversationId, archiveAt, deleteAt, db);
  }

  /**
   * Tâche quotidienne : rattrape les chats manquants, programme l'archivage des trajets finis
   * (ou jamais partis) et supprime les chats échus.
   */
  async applyRetention(): Promise<{ scheduled: number; deleted: number }> {
    for (const rideId of await this.repo.ridesMissingChat()) await this.syncRideChat(rideId);
    const staleHours = await this.settings.get('rides.staleAfterHours');
    const pending = await this.repo.rideChatsToSchedule(new Date(this.clock().getTime() - staleHours * 3_600_000));
    for (const c of pending) await this.scheduleRetention(c.id, c.endedAt ?? this.clock());
    const { deleted } = await this.repo.applyRetention(this.clock());
    return { scheduled: pending.length, deleted };
  }
}
