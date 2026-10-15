import { pathToFileURL } from 'node:url';
import { sectorOf } from '../shared/geo.js';
import { createDatabase, type Db } from './client.js';
import { pointSql, users, vehicles } from './schema.js';
import { PILOT_CAMPUS_ID, seedUsers } from './seed-data.js';

/** Insère les utilisateurs de démonstration ; idempotent (ré-exécutable sans doublon). */
export async function runSeed(db: Db): Promise<void> {
  await db.transaction(async (tx) => {
    const now = new Date();
    for (const user of seedUsers) {
      await tx
        .insert(users)
        .values({
          id: user.id,
          universityEmail: user.email,
          emailVerifiedAt: now,
          firstName: user.firstName,
          lastName: user.lastName,
          homeAddress: user.homeAddress,
          homeLocation: pointSql(user.lat, user.lon),
          homeSector: sectorOf(user),
          campusId: PILOT_CAMPUS_ID,
          roleMode: user.roleMode,
          onboardingCompletedAt: now,
        })
        .onConflictDoNothing({ target: users.id });

      if (user.vehicle) {
        await tx
          .insert(vehicles)
          .values({ id: user.id, userId: user.id, ...user.vehicle })
          .onConflictDoNothing({ target: vehicles.id });
      }
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL manquant');
  const database = createDatabase(url);
  try {
    await runSeed(database.db);
    console.log(`Seed : ${seedUsers.length} étudiants de démonstration`);
  } finally {
    await database.close();
  }
}
