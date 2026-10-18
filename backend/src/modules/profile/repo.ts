import { and, asc, count, eq, isNull, sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import { pauses, pointSql, users, vehicles } from '../../db/schema.js';
import type { OnboardingState, Pause, RoleMode } from './domain.js';

export class ProfileRepo {
  constructor(private readonly db: Db) {}

  async findUser(userId: string) {
    const [user] = await this.db
      .select({
        id: users.id,
        universityEmail: users.universityEmail,
        firstName: users.firstName,
        lastName: users.lastName,
        photoUrl: users.photoUrl,
        studyProgram: users.studyProgram,
        birthYear: users.birthYear,
        interests: users.interests,
        campusId: users.campusId,
        homeAddress: users.homeAddress,
        homeLat: sql<number | null>`ST_Y(${users.homeLocation}::geometry)`,
        homeLon: sql<number | null>`ST_X(${users.homeLocation}::geometry)`,
        homeSector: users.homeSector,
        roleMode: users.roleMode,
        defaultNavApp: users.defaultNavApp,
        reliabilityScore: users.reliabilityScore,
        onboardingSteps: users.onboardingSteps,
      })
      .from(users)
      .where(and(eq(users.id, userId), isNull(users.deletedAt)));
    return user;
  }

  async findPublicUser(userId: string) {
    const [user] = await this.db
      .select({
        id: users.id,
        firstName: users.firstName,
        photoUrl: users.photoUrl,
        reliabilityScore: users.reliabilityScore,
        birthYear: users.birthYear,
        studyProgram: users.studyProgram,
        interests: users.interests,
        ridesCompleted: sql<number>`(SELECT count(*)::int FROM ride_participants p JOIN rides r ON r.id = p.ride_id
          WHERE p.user_id = ${users.id} AND r.status = 'completed' AND p.status IN ('accepted', 'picked_up'))`,
      })
      .from(users)
      .where(and(eq(users.id, userId), isNull(users.deletedAt)));
    return user;
  }

  /**
   * Les deux personnes se sont croisées : même trajet (proposé, demandé ou accepté) ou même
   * conversation. Seules ces personnes voient le profil et la photo de l'autre.
   */
  async related(viewerId: string, userId: string): Promise<boolean> {
    const { rows } = await this.db.execute<{ ok: boolean }>(sql`
      SELECT EXISTS (
        SELECT 1 FROM ride_participants a JOIN ride_participants b ON b.ride_id = a.ride_id
        WHERE a.user_id = ${viewerId} AND b.user_id = ${userId}
          AND a.status NOT IN ('declined') AND b.status NOT IN ('declined')
      ) OR EXISTS (
        SELECT 1 FROM conversation_members a JOIN conversation_members b ON b.conversation_id = a.conversation_id
        WHERE a.user_id = ${viewerId} AND b.user_id = ${userId}
      ) AS ok`);
    return rows[0]?.ok === true;
  }

  async setPhoto(userId: string, photo: { contentType: string; data: Buffer; url: string } | null): Promise<void> {
    await this.db.transaction(async (tx) => {
      if (photo) {
        await tx.execute(sql`
          INSERT INTO user_photos (user_id, content_type, data, updated_at)
          VALUES (${userId}, ${photo.contentType}, ${photo.data}, now())
          ON CONFLICT (user_id) DO UPDATE SET content_type = EXCLUDED.content_type, data = EXCLUDED.data, updated_at = now()`);
      } else {
        await tx.execute(sql`DELETE FROM user_photos WHERE user_id = ${userId}`);
      }
      await tx.update(users).set({ photoUrl: photo?.url ?? null }).where(eq(users.id, userId));
    });
  }

  async photo(userId: string): Promise<{ contentType: string; data: Buffer } | undefined> {
    const { rows } = await this.db.execute<{ content_type: string; data: Buffer }>(sql`
      SELECT p.content_type, p.data FROM user_photos p JOIN users u ON u.id = p.user_id
      WHERE p.user_id = ${userId} AND u.deleted_at IS NULL`);
    const row = rows[0];
    return row ? { contentType: row.content_type, data: row.data } : undefined;
  }

  async findVehicle(userId: string) {
    const [vehicle] = await this.db.select().from(vehicles).where(eq(vehicles.userId, userId));
    return vehicle;
  }

  async updateUser(
    userId: string,
    values: Partial<{
      firstName: string;
      lastName: string;
      studyProgram: string | null;
      birthYear: number | null;
      interests: string[];
      roleMode: RoleMode;
      defaultNavApp: string | null;
      onboardingSteps: OnboardingState;
      onboardingCompletedAt: Date;
    }>,
  ): Promise<void> {
    await this.db.update(users).set(values).where(eq(users.id, userId));
  }

  /**
   * Fusion atomique dans le JSON (pas de lecture-modification-écriture) : deux étapes
   * validées en même temps ne s'écrasent pas.
   */
  async setOnboardingStep(userId: string, step: string, status: string): Promise<OnboardingState> {
    const [row] = await this.db
      .update(users)
      .set({ onboardingSteps: sql`${users.onboardingSteps} || jsonb_build_object(${step}::text, ${status}::text)` })
      .where(eq(users.id, userId))
      .returning({ steps: users.onboardingSteps });
    return (row?.steps ?? {});
  }

  async updateHome(userId: string, home: { address: string; lat: number; lon: number; sector: string }) {
    await this.db
      .update(users)
      .set({ homeAddress: home.address, homeLocation: pointSql(home.lat, home.lon), homeSector: home.sector })
      .where(eq(users.id, userId));
  }

  async upsertVehicle(
    userId: string,
    vehicle: {
      consumptionLPer100km: string;
      defaultSeats: number;
      maxDetourMinutes: number;
      model: string | null;
      color: string | null;
    },
  ): Promise<void> {
    await this.db
      .insert(vehicles)
      .values({ userId, ...vehicle })
      .onConflictDoUpdate({ target: vehicles.userId, set: vehicle });
  }

  /** Supprime le véhicule et repasse en passager, atomiquement. */
  async deleteVehicle(userId: string, roleMode: RoleMode): Promise<boolean> {
    return this.db.transaction(async (tx) => {
      const deleted = await tx.delete(vehicles).where(eq(vehicles.userId, userId)).returning({ id: vehicles.id });
      await tx.update(users).set({ roleMode }).where(eq(users.id, userId));
      return deleted.length > 0;
    });
  }

  async listPauses(userId: string) {
    return this.db
      .select({ id: pauses.id, startsOn: pauses.startsOn, endsOn: pauses.endsOn, recurrence: pauses.recurrence, repeatUntil: pauses.repeatUntil })
      .from(pauses)
      .where(eq(pauses.userId, userId))
      .orderBy(asc(pauses.startsOn));
  }

  async countPauses(userId: string): Promise<number> {
    const [row] = await this.db.select({ n: count() }).from(pauses).where(eq(pauses.userId, userId));
    return row?.n ?? 0;
  }

  async insertPause(userId: string, pause: Pause) {
    const [created] = await this.db
      .insert(pauses)
      .values({ userId, ...pause })
      .returning({ id: pauses.id, startsOn: pauses.startsOn, endsOn: pauses.endsOn, recurrence: pauses.recurrence, repeatUntil: pauses.repeatUntil });
    return created!;
  }

  /** Ne supprime que les pauses de l'utilisateur : celles des autres sont « introuvables ». */
  async deletePause(userId: string, pauseId: string): Promise<boolean> {
    const deleted = await this.db
      .delete(pauses)
      .where(and(eq(pauses.id, pauseId), eq(pauses.userId, userId)))
      .returning({ id: pauses.id });
    return deleted.length > 0;
  }
}
