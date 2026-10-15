/**
 * Schéma Drizzle (sous-ensemble utilisé par le code). La source du schéma physique reste
 * les migrations SQL de `migrations/`, issues de `docs/data-model.sql`. Chaque module
 * ajoute ici les tables qu'il manipule.
 */
import { sql } from 'drizzle-orm';
import {
  customType,
  jsonb,
  numeric,
  pgEnum,
  pgTable,
  smallint,
  text,
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
