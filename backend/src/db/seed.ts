import { pathToFileURL } from 'node:url';
import { hash } from '@node-rs/argon2';
import { manualSlots } from '../modules/calendar/domain.js';
import { ONBOARDING_STEPS } from '../modules/profile/domain.js';
import { sectorOf } from '../shared/geo.js';
import { parisDateOf } from '../shared/time.js';
import { createDatabase, type Db } from './client.js';
import { manualScheduleDays, pointSql, scheduleSlots, users, vehicles } from './schema.js';
import { DEMO_PASSWORD, PILOT_CAMPUS_ID, seedUsers, vehicleId } from './seed-data.js';

/**
 * Étudiants de démonstration, onboarding terminé, semaine type sur `horizonDays` jours à
 * partir de `today`. Idempotent : ré-exécutable sans doublon.
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
