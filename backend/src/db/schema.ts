/**
 * Schéma Drizzle (sous-ensemble utilisé par le code). La source du schéma physique reste
 * les migrations SQL de `migrations/`, issues de `docs/data-model.sql`. Chaque module
 * ajoute ici les tables qu'il manipule.
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  customType,
  date,
  integer,
  jsonb,
  primaryKey,
  numeric,
  pgEnum,
  pgTable,
  smallint,
  text,
  time,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

/** Point WGS84 (`geography(Point,4326)`). Écriture via `pointSql()`, lecture via ST_X/ST_Y. */
export const geographyPoint = customType<{ data: string; driverData: string }>({
  dataType: () => 'geography(Point,4326)',
});

export function pointSql(lat: number, lon: number) {
  return sql`ST_SetSRID(ST_MakePoint(${lon}, ${lat}), 4326)::geography`;
}

export const roleMode = pgEnum('role_mode', ['auto', 'always_driver', 'always_passenger']);

export const appSettings = pgTable('app_settings', {
  key: text('key').primaryKey(),
  value: jsonb('value').notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const campuses = pgTable('campuses', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  location: geographyPoint('location').notNull(),
});

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  universityEmail: text('university_email').notNull().unique(),
  emailVerifiedAt: timestamp('email_verified_at', { withTimezone: true }),
  passwordHash: text('password_hash'),
  firstName: text('first_name').notNull(),
  lastName: text('last_name').notNull(),
  photoUrl: text('photo_url'),
  homeAddress: text('home_address'),
  homeLocation: geographyPoint('home_location'),
  homeSector: text('home_sector'),
  campusId: uuid('campus_id'),
  roleMode: roleMode('role_mode').notNull().default('always_passenger'),
  defaultNavApp: text('default_nav_app'),
  onboardingCompletedAt: timestamp('onboarding_completed_at', { withTimezone: true }),
  reliabilityScore: numeric('reliability_score', { precision: 4, scale: 3 }).notNull().default('0.800'),
  pausedUntil: timestamp('paused_until', { withTimezone: true }),
  onboardingSteps: jsonb('onboarding_steps').$type<Record<string, 'done' | 'skipped'>>().notNull().default({}),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const vehicles = pgTable('vehicles', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  consumptionLPer100km: numeric('consumption_l_per_100km', { precision: 4, scale: 1 }).notNull(),
  defaultSeats: smallint('default_seats').notNull(),
  maxDetourMinutes: smallint('max_detour_minutes').notNull().default(10),
});

export const pauses = pgTable('pauses', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  startsOn: date('starts_on').notNull(),
  endsOn: date('ends_on').notNull(),
  recurrence: text('recurrence').$type<'weekly:2' | 'weekly:3' | 'weekly:4'>(),
});

export const verificationCodes = pgTable('verification_codes', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull(),
  codeHash: text('code_hash').notNull(),
  purpose: text('purpose').notNull().default('signup'),
  attempts: smallint('attempts').notNull().default(0),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  consumedAt: timestamp('consumed_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const refreshTokens = pgTable('refresh_tokens', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  familyId: uuid('family_id').notNull(),
  tokenHash: text('token_hash').notNull().unique(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  usedAt: timestamp('used_at', { withTimezone: true }),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const bytea = customType<{ data: Buffer; driverData: Buffer }>({ dataType: () => 'bytea' });

export const calendarConnections = pgTable('calendar_connections', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  provider: text('provider').notNull(),
  encryptedCredentials: bytea('encrypted_credentials'),
  consentedAt: timestamp('consented_at', { withTimezone: true }).notNull(),
  lastSyncedAt: timestamp('last_synced_at', { withTimezone: true }),
  lastError: text('last_error'),
});

export const manualScheduleDays = pgTable(
  'manual_schedule_days',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    weekday: smallint('weekday').notNull(),
    startTime: time('start_time').notNull(),
    endTime: time('end_time').notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.weekday] })],
);

export const scheduleSlots = pgTable('schedule_slots', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  day: date('day').notNull(),
  startAt: timestamp('start_at', { withTimezone: true }).notNull(),
  endAt: timestamp('end_at', { withTimezone: true }).notNull(),
  source: text('source').$type<'calendar' | 'manual'>().notNull(),
});

export const rideStatus = pgEnum('ride_status', ['proposed', 'confirmed', 'in_progress', 'completed', 'cancelled']);
export const participantRole = pgEnum('participant_role', ['driver', 'passenger']);
export const participantStatus = pgEnum('participant_status', [
  'proposed',
  'requested',
  'accepted',
  'declined',
  'picked_up',
  'absent',
  'cancelled',
]);

export const rides = pgTable('rides', {
  id: uuid('id').primaryKey().defaultRandom(),
  driverId: uuid('driver_id')
    .notNull()
    .references(() => users.id),
  direction: text('direction').$type<'to_campus' | 'from_campus'>().notNull(),
  campusId: uuid('campus_id')
    .notNull()
    .references(() => campuses.id),
  day: date('day'),
  targetTime: timestamp('target_time', { withTimezone: true }).notNull(),
  seatsTotal: smallint('seats_total').notNull(),
  status: rideStatus('status').notNull().default('proposed'),
  distanceM: integer('distance_m'),
  durationS: integer('duration_s'),
  routeEstimated: boolean('route_estimated').notNull().default(false),
  plannedAt: timestamp('planned_at', { withTimezone: true }),
  startedAt: timestamp('started_at', { withTimezone: true }),
  endedAt: timestamp('ended_at', { withTimezone: true }),
  finalTotalCostCents: integer('final_total_cost_cents'),
  estimatedTotalCostCents: integer('estimated_total_cost_cents'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const rideParticipants = pgTable(
  'ride_participants',
  {
    rideId: uuid('ride_id')
      .notNull()
      .references(() => rides.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id),
    role: participantRole('role').notNull(),
    status: participantStatus('status').notNull().default('proposed'),
    detourS: integer('detour_s'),
    pickupLabel: text('pickup_label'),
    useMeetingPoint: boolean('use_meeting_point').notNull().default(false),
    stopOrder: smallint('stop_order'),
    eta: timestamp('eta', { withTimezone: true }),
    presenceValidatedAt: timestamp('presence_validated_at', { withTimezone: true }),
    amountCents: integer('amount_cents'),
    cancelledAt: timestamp('cancelled_at', { withTimezone: true }),
    pickedUpAt: timestamp('picked_up_at', { withTimezone: true }),
  },
  (t) => [primaryKey({ columns: [t.rideId, t.userId] })],
);

export const proposalDeclines = pgTable(
  'proposal_declines',
  {
    userId: uuid('user_id').notNull(),
    otherUserId: uuid('other_user_id').notNull(),
    day: date('day').notNull(),
    direction: text('direction').$type<'to_campus' | 'from_campus'>().notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.otherUserId, t.day, t.direction] })],
);

export const matchingRuns = pgTable('matching_runs', {
  week: text('week').primaryKey(),
  generatedAt: timestamp('generated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const searchQuota = pgTable(
  'search_quota',
  {
    userId: uuid('user_id').notNull(),
    day: date('day').notNull(),
    count: integer('count').notNull().default(0),
  },
  (t) => [primaryKey({ columns: [t.userId, t.day] })],
);
