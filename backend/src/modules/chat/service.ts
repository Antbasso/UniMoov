import { AppError } from '../../shared/errors.js';
import { imageTypeOf } from '../../shared/images.js';
import type { Notifier } from '../../shared/notifications/notifier.js';
import type { SettingsService } from '../settings/service.js';
import type { UserHub } from './hub.js';
import { parisDateOf, parisToUtc } from '../../shared/time.js';
import type { CarpoolInfo, ChatRepo, ConversationKind, ConversationRow, DbOrTx, MessageRow } from './repo.js';

const DAY_MS = 86_400_000;

export interface MessageView {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  createdAt: Date;
  /** Proposition de covoiturage (offre d'un conducteur ou demande d'un passager). */
  carpool: CarpoolInfo | null;
  /** Qui a réagi, et comment (une réaction par personne) : l'app regroupe et repère la sienne. */
  reactions: { userId: string; emoji: string }[];
  /** Photo jointe, servie aux seuls membres ; `body` est alors sa légende (peut être vide). */
  photoUrl: string | null;
  /** Message auquel celui-ci répond (début du texte), cité au-dessus de la réponse. */
  replyTo: MessageRow['replyTo'];
}

/** Rejoindre une voiture par accord (matching) : passager accepté directement. */
export type JoinByAgreement = (rideId: string, passengerId: string) => Promise<void>;

/** Créer un trajet que je conduis (matching), renvoie son identifiant. */
export type CreateRide = (
  driverId: string,
  input: { day: string; direction: 'to_campus' | 'from_campus'; time: string },
) => Promise<string>;

export interface ConversationView {
  id: string;
  kind: ConversationKind;
  title: string | null;
  rideId: string | null;
  /** Chat de trajet : jour et sens, pour le distinguer des autres. */
  ride: { day: string; direction: 'to_campus' | 'from_campus' } | null;
  /** Lecture seule : chat de trajet archivé. */
  archived: boolean;
  createdBy: string | null;
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
  carpool: m.carpool,
  reactions: m.reactions,
  photoUrl: m.hasPhoto ? `/api/v1/conversations/${m.conversationId}/messages/${m.id}/photo` : null,
  replyTo: m.replyTo,
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
    private readonly join: JoinByAgreement = () => Promise.reject(new Error('Covoiturage de groupe non branché')),
    private readonly createRide: CreateRide = () => Promise.reject(new Error('Création de trajet non branchée')),
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
      createdBy: c.kind === 'group' ? c.createdBy : null,
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

  /** Groupe dont je suis membre (404 sinon), modifiable (409 pour un privé ou un trajet). */
  private async group(userId: string, conversationId: string): Promise<ConversationRow> {
    const c = await this.member(userId, conversationId);
    if (c.kind !== 'group') throw new AppError(409, 'not_a_group', 'Seul un groupe se gère');
    return c;
  }

  /** Renommer le groupe (tout membre, comme dans une messagerie). */
  async rename(userId: string, conversationId: string, title: string): Promise<ConversationView> {
    await this.group(userId, conversationId);
    await this.repo.rename(conversationId, title.trim());
    return this.get(userId, conversationId);
  }

  /** Ajouter des personnes au groupe : seulement celles que j'ai croisées sur un trajet. */
  async addMembers(userId: string, conversationId: string, memberIds: string[]): Promise<ConversationView> {
    await this.group(userId, conversationId);
    const current = new Set((await this.repo.members(conversationId)).map((m) => m.userId));
    const added = [...new Set(memberIds)].filter((id) => !current.has(id));
    if (added.length === 0) return this.get(userId, conversationId);
    if (!(await this.repo.sharedRideWithAll(userId, added))) {
      throw new AppError(403, 'not_a_contact', "Tu ne peux ajouter que des personnes croisées sur un trajet");
    }
    if (current.size + added.length > (await this.settings.get('chat.maxGroupMembers'))) {
      throw new AppError(422, 'group_too_large', 'Ce groupe compte trop de personnes');
    }
    await this.repo.addMembers(conversationId, added, this.clock());
    return this.get(userId, conversationId);
  }

  /** Retirer quelqu'un du groupe : réservé au créateur (chacun peut quitter de lui-même). */
  async removeMember(userId: string, conversationId: string, memberId: string): Promise<ConversationView> {
    const c = await this.group(userId, conversationId);
    if (memberId === userId) throw new AppError(409, 'use_leave', 'Pour partir, quitte le groupe');
    if (c.createdBy !== userId) throw new AppError(403, 'forbidden', 'Seul le créateur du groupe peut retirer quelqu’un');
    await this.repo.removeMembers(conversationId, [memberId]);
    return this.get(userId, conversationId);
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
  async send(userId: string, conversationId: string, body: string, replyToId: string | null = null): Promise<MessageView> {
    const text = body.trim();
    if (!text) throw new AppError(400, 'validation_error', 'Requête invalide');
    const message = await this.repo.transaction(async (tx) => {
      // Sous le verrou : un archivage simultané n'accepte pas de nouveau message.
      const c = await this.repo.conversation(conversationId, tx, true);
      if (!c || !(await this.repo.isMember(conversationId, userId, tx))) throw new AppError(404, 'not_found', 'Ressource introuvable');
      if (this.archived(c)) throw new AppError(409, 'conversation_archived', 'Cette conversation est archivée');
      await this.assertReplyable(conversationId, replyToId, tx);
      return this.repo.insertMessage(conversationId, userId, text, this.clock(), tx, null, null, replyToId);
    });
    return this.publish(userId, conversationId, message);
  }

  /**
   * Photo dans une conversation (JPEG ou PNG, 600 Ko au plus, réduite par l'app), avec une
   * légende facultative. Gardée en base et supprimée avec le message (rétention).
   */
  async sendPhoto(
    userId: string,
    conversationId: string,
    contentType: string,
    data: Buffer,
    caption: string,
    replyToId: string | null = null,
  ): Promise<MessageView> {
    const type = imageTypeOf(data);
    if (!type || type !== contentType) throw new AppError(400, 'photo_invalid', 'Choisis une photo JPEG ou PNG');
    const message = await this.repo.transaction(async (tx) => {
      const c = await this.repo.conversation(conversationId, tx, true);
      if (!c || !(await this.repo.isMember(conversationId, userId, tx))) throw new AppError(404, 'not_found', 'Ressource introuvable');
      if (this.archived(c)) throw new AppError(409, 'conversation_archived', 'Cette conversation est archivée');
      await this.assertReplyable(conversationId, replyToId, tx);
      return this.repo.insertMessage(conversationId, userId, caption.trim(), this.clock(), tx, null, { contentType: type, data }, replyToId);
    });
    return this.publish(userId, conversationId, message);
  }

  /** On ne cite qu'un message de la même conversation. */
  private async assertReplyable(conversationId: string, replyToId: string | null, tx: DbOrTx): Promise<void> {
    if (replyToId && !(await this.repo.message(conversationId, replyToId, tx))) {
      throw new AppError(404, 'not_found', 'Ressource introuvable');
    }
  }

  /** Photo d'un message, pour les membres seulement (404 sinon). */
  async photo(userId: string, conversationId: string, messageId: string): Promise<{ contentType: string; data: Buffer }> {
    await this.member(userId, conversationId);
    const photo = await this.repo.photo(conversationId, messageId);
    if (!photo) throw new AppError(404, 'not_found', 'Ressource introuvable');
    return photo;
  }

  /** Réagir à un message (une réaction par personne), ou retirer sa réaction ; tous voient la mise à jour. */
  async react(userId: string, conversationId: string, messageId: string, emoji: string | null): Promise<MessageView> {
    const c = await this.member(userId, conversationId);
    if (this.archived(c)) throw new AppError(409, 'conversation_archived', 'Cette conversation est archivée');
    if (!(await this.repo.message(conversationId, messageId))) throw new AppError(404, 'not_found', 'Ressource introuvable');
    await this.repo.setReaction(messageId, userId, emoji, this.clock());
    return this.publish(userId, conversationId, (await this.repo.message(conversationId, messageId))!, false);
  }

  /** Envoi en direct aux membres connectés, en push aux autres (préférence « chat »). */
  private async publish(userId: string, conversationId: string, message: MessageRow, push = true): Promise<MessageView> {
    const members = await this.repo.members(conversationId);
    const view = messageView(message);
    this.hub.send(members.map((m) => m.userId), { type: 'message', message: view });
    const sender = members.find((m) => m.userId === userId);
    const offline = members.filter((m) => m.userId !== userId && !this.hub.isOnline(m.userId)).map((m) => m.userId);
    if (push && offline.length > 0) {
      // En tâche de fond : un FCM lent ne retarde pas la réponse (sinon renvoi et doublon).
      void this.notifier
        .notify(offline, { type: 'chat_message', conversationId, senderFirstName: sender?.firstName ?? '' })
        .catch(() => undefined);
    }
    return view;
  }

  /**
   * Proposition de covoiturage dans une conversation créée à la main (groupe ou privé) :
   * offre (« je conduis, qui monte ? », sur un trajet que je conduis) ou demande (« je
   * cherche une voiture ce jour-là »). Le texte est écrit par le serveur.
   */
  async postCarpool(
    userId: string,
    conversationId: string,
    input:
      | { kind: 'offer'; rideId: string }
      | { kind: 'offer'; create: { day: string; direction: 'to_campus' | 'from_campus'; time: string } }
      | { kind: 'request'; day: string; direction: 'to_campus' | 'from_campus'; time?: string | undefined },
  ): Promise<MessageView> {
    const c = await this.member(userId, conversationId);
    if (c.kind === 'ride') throw new AppError(409, 'carpool_not_here', 'Propose un trajet dans un groupe ou une conversation privée');
    if (this.archived(c)) throw new AppError(409, 'conversation_archived', 'Cette conversation est archivée');
    const today = parisDateOf(this.clock());
    let carpool: { kind: 'offer' | 'request'; rideId: string | null; day: string; direction: string; time?: Date | null };
    if (input.kind === 'offer') {
      // Trajet créé pour l'occasion (je conduis ce jour-là, à cette heure), puis proposé.
      const rideId = 'create' in input ? await this.createRide(userId, input.create) : input.rideId;
      const ride = await this.repo.drivenOpenRide(userId, { rideId }, today);
      if (!ride) throw new AppError(409, 'ride_unavailable', 'Ce trajet ne peut plus être proposé');
      carpool = { kind: 'offer', rideId: ride.id, day: ride.day, direction: ride.direction };
    } else {
      if (input.day < today) throw new AppError(400, 'validation_error', 'Choisis un jour à venir');
      carpool = {
        kind: 'request',
        rideId: null,
        day: input.day,
        direction: input.direction,
        time: input.time ? parisToUtc(input.day, input.time) : null,
      };
    }
    const sens = carpool.direction === 'to_campus' ? 'aller' : 'retour';
    const body = carpool.kind === 'offer' ? `Je propose un trajet (${sens}, ${carpool.day}).` : `Je cherche un trajet (${sens}, ${carpool.day}).`;
    const message = await this.repo.transaction(async (tx) => {
      const locked = await this.repo.conversation(conversationId, tx, true);
      if (!locked || this.archived(locked)) throw new AppError(409, 'conversation_archived', 'Cette conversation est archivée');
      return this.repo.insertMessage(conversationId, userId, body, this.clock(), tx, carpool);
    });
    return this.publish(userId, conversationId, message);
  }

  /**
   * Accepter une proposition : offre, je monte dans la voiture proposée ; demande, je prends la
   * personne dans la voiture que je conduis ce jour-là. Les deux ont dit oui : place acceptée.
   */
  async acceptCarpool(userId: string, conversationId: string, messageId: string): Promise<MessageView> {
    const c = await this.member(userId, conversationId);
    if (this.archived(c)) throw new AppError(409, 'conversation_archived', 'Cette conversation est archivée');
    const message = await this.repo.message(conversationId, messageId);
    const carpool = message?.carpool;
    if (!message || !carpool) throw new AppError(404, 'not_found', 'Ressource introuvable');
    if (message.senderId === userId) throw new AppError(409, 'own_carpool', "C'est ta propre proposition");
    const today = parisDateOf(this.clock());
    if (carpool.day < today) throw new AppError(409, 'ride_unavailable', 'Ce trajet est passé');
    let rideId: string;
    let passengerId: string;
    if (carpool.kind === 'offer') {
      if (!carpool.rideId) throw new AppError(409, 'ride_unavailable', 'Ce trajet ne peut plus te prendre');
      rideId = carpool.rideId;
      passengerId = userId;
    } else {
      const ride = await this.repo.drivenOpenRide(userId, { day: carpool.day, direction: carpool.direction }, today);
      if (!ride) throw new AppError(409, 'no_ride_that_day', 'Tu ne conduis pas ce jour-là');
      rideId = ride.id;
      passengerId = message.senderId;
    }
    await this.join(rideId, passengerId);
    await this.repo.addCarpoolJoin(messageId, passengerId, rideId);
    // Mise à jour du message chez tous (« Léa monte »), sans nouveau push.
    return this.publish(userId, conversationId, (await this.repo.message(conversationId, messageId))!, false);
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
