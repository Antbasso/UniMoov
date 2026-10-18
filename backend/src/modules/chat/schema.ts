import { z } from 'zod';

export const conversationParams = z.object({ id: z.uuid() });

const member = z.strictObject({ userId: z.uuid(), firstName: z.string(), photoUrl: z.string().nullable() });

const direction = z.enum(['to_campus', 'from_campus']);

export const message = z.strictObject({
  id: z.uuid(),
  conversationId: z.uuid(),
  senderId: z.uuid(),
  body: z.string(),
  createdAt: z.date(),
  carpool: z
    .strictObject({
      kind: z.enum(['offer', 'request']),
      rideId: z.uuid().nullable(),
      day: z.iso.date(),
      direction,
      time: z.date().nullable(),
      joined: z.array(z.strictObject({ userId: z.uuid(), firstName: z.string(), rideId: z.uuid() })),
    })
    .nullable(),
  reactions: z.array(z.strictObject({ userId: z.uuid(), emoji: z.string() })),
  photoUrl: z.string().nullable(),
});

/** Un emoji, quel qu'il soit (teintes de peau, drapeaux, séquences ZWJ compris), rien d'autre. */
const EMOJI = /^(?=.*[\p{Extended_Pictographic}\p{Regional_Indicator}])(?:[\p{Extended_Pictographic}\p{Regional_Indicator}\p{Emoji_Modifier}#*0-9]|\u200D|\uFE0F|\u20E3)+$/u;
export const reactionBody = z.object({ emoji: z.string().min(1).max(16).regex(EMOJI) });
export const renameBody = z.object({ title: z.string().trim().min(1).max(60) });
export const addMembersBody = z.object({ memberIds: z.array(z.uuid()).min(1).max(49) });
export const memberParams = z.object({ id: z.uuid(), userId: z.uuid() });
export const photoQuery = z.object({ caption: z.string().max(1000).default('') });

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);

/** Offre sur un trajet existant (`rideId`) ou créé pour l'occasion (`create`) ; demande avec heure facultative. */
export const carpoolBody = z.union([
  z.object({ kind: z.literal('offer'), rideId: z.uuid() }),
  z.object({ kind: z.literal('offer'), create: z.object({ day: z.iso.date(), direction, time: hhmm }) }),
  z.object({ kind: z.literal('request'), day: z.iso.date(), direction, time: hhmm.optional() }),
]);
export const messageParams = z.object({ id: z.uuid(), messageId: z.uuid() });

export const conversation = z.strictObject({
  id: z.uuid(),
  kind: z.enum(['direct', 'group', 'ride']),
  title: z.string().nullable(),
  rideId: z.uuid().nullable(),
  ride: z.strictObject({ day: z.string(), direction: z.enum(['to_campus', 'from_campus']) }).nullable(),
  archived: z.boolean(),
  /** Créateur d'un groupe (peut retirer des membres) ; null pour un chat de trajet. */
  createdBy: z.uuid().nullable(),
  members: z.array(member),
  unread: z.number().int(),
  lastMessage: message.nullable(),
});

export const conversationsResponse = z.strictObject({ conversations: z.array(conversation) });
export const contactsResponse = z.strictObject({ contacts: z.array(member) });

export const createBody = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('direct'), memberIds: z.array(z.uuid()).length(1) }),
  z.object({ kind: z.literal('group'), memberIds: z.array(z.uuid()).min(1).max(49), title: z.string().trim().min(1).max(60) }),
]);

export const messagesQuery = z.object({
  before: z.iso.datetime({ offset: true }).optional(),
  beforeId: z.uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});
export const messagesResponse = z.strictObject({ messages: z.array(message) });
export const sendBody = z.object({ body: z.string().trim().min(1).max(2000) });
