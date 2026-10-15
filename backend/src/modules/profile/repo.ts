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
      })
      .from(users)
      .where(and(eq(users.id, userId), isNull(users.deletedAt)));
    return user;
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
    vehicle: { consumptionLPer100km: string; defaultSeats: number; maxDetourMinutes: number },
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
      .select({ id: pauses.id, startsOn: pauses.startsOn, endsOn: pauses.endsOn, recurrence: pauses.recurrence })
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
      .returning({ id: pauses.id, startsOn: pauses.startsOn, endsOn: pauses.endsOn, recurrence: pauses.recurrence });
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
