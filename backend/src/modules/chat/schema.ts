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
      joined: z.array(z.strictObject({ userId: z.uuid(), firstName: z.string() })),
    })
    .nullable(),
});

export const carpoolBody = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('offer'), rideId: z.uuid() }),
  z.object({ kind: z.literal('request'), day: z.iso.date(), direction }),
]);
export const messageParams = z.object({ id: z.uuid(), messageId: z.uuid() });

export const conversation = z.strictObject({
  id: z.uuid(),
  kind: z.enum(['direct', 'group', 'ride']),
  title: z.string().nullable(),
  rideId: z.uuid().nullable(),
  ride: z.strictObject({ day: z.string(), direction: z.enum(['to_campus', 'from_campus']) }).nullable(),
  archived: z.boolean(),
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
