import { pathToFileURL } from 'node:url';
import { hash } from '@node-rs/argon2';
import { manualSlots } from '../modules/calendar/domain.js';
import { ONBOARDING_STEPS } from '../modules/profile/domain.js';
import { sectorOf } from '../shared/geo.js';
import { parisDateOf } from '../shared/time.js';
import { sql } from 'drizzle-orm';
import { createDatabase, type Db } from './client.js';
import { manualScheduleDays, pointSql, scheduleSlots, users, vehicles } from './schema.js';
import { DEMO_PASSWORD, PILOT_CAMPUS_ID, seedUsers, vehicleId } from './seed-data.js';

/** Solde de départ des passagers de démonstration (portefeuille factice). */
export const SEED_PASSENGER_BALANCE_CENTS = 2000;

/**
 * Étudiants de démonstration, onboarding terminé, semaine type sur `horizonDays` jours à
 * partir de `today` ; les passagers (sans véhicule) ont un solde de départ, sans quoi ils ne
 * peuvent pas accepter de trajet. Idempotent : ré-exécutable sans doublon.
 */
export async function runSeed(db: Db, { today = parisDateOf(new Date()), horizonDays = 28 } = {}): Promise<void> {
  const passwordHash = await hash(DEMO_PASSWORD);
  const onboardingSteps = Object.fromEntries(ONBOARDING_STEPS.map((s) => [s, 'done' as const]));
  await db.transaction(async (tx) => {
    const now = new Date();
    for (const user of seedUsers) {
      await tx
        .insert(users)
        .values({
          id: user.id,
          universityEmail: user.email,
          emailVerifiedAt: now,
          passwordHash,
          firstName: user.firstName,
          lastName: user.lastName,
          homeAddress: user.homeAddress,
          homeLocation: pointSql(user.lat, user.lon),
          homeSector: sectorOf(user),
          campusId: PILOT_CAMPUS_ID,
          roleMode: user.roleMode,
          onboardingSteps,
          onboardingCompletedAt: now,
        })
        .onConflictDoNothing({ target: users.id });

      if (user.vehicle) {
        await tx
          .insert(vehicles)
          .values({ id: vehicleId(user.id), userId: user.id, ...user.vehicle })
          .onConflictDoNothing({ target: vehicles.id });
      }

      if (!user.vehicle) {
        // Recharge factice, écritures équilibrées comme une vraie (registre en écriture seule).
        await tx.execute(sql`
          WITH op AS (SELECT gen_random_uuid() AS id)
          INSERT INTO wallet_ledger (idempotency_key, account, kind, amount_cents, operation_id)
          SELECT k, a, 'topup', amt, op.id FROM op, (VALUES
            (${`seed:topup:${user.id}:clearing`}, 'provider:clearing', ${-SEED_PASSENGER_BALANCE_CENTS}::int),
            (${`seed:topup:${user.id}`}, ${`user:${user.id}`}, ${SEED_PASSENGER_BALANCE_CENTS}::int)
          ) AS v(k, a, amt)
          ON CONFLICT (idempotency_key) DO NOTHING`);
        await tx.execute(sql`
          INSERT INTO wallets (user_id, balance_cents)
          VALUES (${user.id}, (SELECT coalesce(sum(amount_cents), 0) FROM wallet_ledger WHERE account = ${`user:${user.id}`}))
          ON CONFLICT (user_id) DO UPDATE SET balance_cents = EXCLUDED.balance_cents`);
      }

      const template = Object.entries(user.week).map(([weekday, [startTime, endTime]]) => ({
        weekday: Number(weekday),
        startTime,
        endTime,
      }));
      await tx.insert(manualScheduleDays).values(template.map((d) => ({ userId: user.id, ...d }))).onConflictDoNothing();
      const slots = manualSlots(template, today, horizonDays);
      await tx
        .insert(scheduleSlots)
        .values(slots.map((s) => ({ userId: user.id, source: 'manual' as const, day: s.day, startAt: s.start, endAt: s.end })))
        .onConflictDoNothing();
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL manquant');
  const database = createDatabase(url);
  try {
    await runSeed(database.db);
    console.log(`Seed : ${seedUsers.length} étudiants de démonstration (mot de passe : ${DEMO_PASSWORD})`);
  } finally {
    await database.close();
  }
}
