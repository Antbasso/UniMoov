import { and, asc, desc, eq, isNull, sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import { campuses, refreshTokens, users, verificationCodes } from '../../db/schema.js';

type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
export type DbOrTx = Db | Tx;

export class AuthRepo {
  constructor(private readonly db: Db) {}

  transaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return this.db.transaction(fn);
  }

  async findUserByEmail(email: string, db: DbOrTx = this.db) {
    const [user] = await db
      .select({ id: users.id, passwordHash: users.passwordHash, deletedAt: users.deletedAt })
      .from(users)
      .where(eq(users.universityEmail, email));
    return user;
  }

  async latestCode(email: string, db: DbOrTx = this.db) {
    const [code] = await db
      .select()
      .from(verificationCodes)
      .where(eq(verificationCodes.email, email))
      .orderBy(desc(verificationCodes.createdAt))
      .limit(1)
      .for('update');
    return code;
  }

  async replaceCode(email: string, codeHash: string, now: Date, expiresAt: Date): Promise<void> {
    await this.db.transaction(async (tx) => {
      // Un seul code actif par adresse : les précédents sont consommés.
      await tx
        .update(verificationCodes)
        .set({ consumedAt: now })
        .where(and(eq(verificationCodes.email, email), isNull(verificationCodes.consumedAt)));
      await tx.insert(verificationCodes).values({ email, codeHash, expiresAt, createdAt: now });
    });
  }

  /** Codes demandés pour cette adresse depuis `since` (plafond quotidien). */
  async codesSince(email: string, since: Date): Promise<number> {
    const { rows } = await this.db.execute<{ n: number }>(sql`
      SELECT count(*)::int AS n FROM verification_codes WHERE email = ${email} AND created_at > ${since}`);
    return rows[0]?.n ?? 0;
  }

  /** Adresse bloquée après trop d'échecs de connexion (`null` : libre). */
  async loginLockedUntil(email: string, now: Date): Promise<Date | null> {
    const { rows } = await this.db.execute<{ locked_until: Date | null }>(sql`
      SELECT locked_until FROM login_failures WHERE email = ${email} AND locked_until > ${now}`);
    return rows[0]?.locked_until ?? null;
  }

  /** Compte un échec dans la fenêtre ; au seuil, bloque l'adresse. */
  async recordLoginFailure(email: string, now: Date, policy: { maxFailures: number; lockMinutes: number }): Promise<void> {
    const windowStart = new Date(now.getTime() - policy.lockMinutes * 60_000);
    const lockUntil = new Date(now.getTime() + policy.lockMinutes * 60_000);
    await this.db.execute(sql`
      INSERT INTO login_failures (email, failures, window_start) VALUES (${email}, 1, ${now})
      ON CONFLICT (email) DO UPDATE SET
        failures = CASE WHEN login_failures.window_start < ${windowStart} THEN 1 ELSE login_failures.failures + 1 END,
        window_start = CASE WHEN login_failures.window_start < ${windowStart} THEN ${now} ELSE login_failures.window_start END,
        locked_until = CASE
          WHEN login_failures.window_start >= ${windowStart} AND login_failures.failures + 1 >= ${policy.maxFailures}
          THEN ${lockUntil} ELSE login_failures.locked_until END`);
  }

  async clearLoginFailures(email: string): Promise<void> {
    await this.db.execute(sql`DELETE FROM login_failures WHERE email = ${email}`);
  }

  async incrementAttempts(id: string, db: DbOrTx = this.db): Promise<void> {
    await db
      .update(verificationCodes)
      .set({ attempts: sql`${verificationCodes.attempts} + 1` })
      .where(eq(verificationCodes.id, id));
  }

  async consumeCode(id: string, now: Date, db: DbOrTx = this.db): Promise<void> {
    await db.update(verificationCodes).set({ consumedAt: now }).where(eq(verificationCodes.id, id));
  }

  async defaultCampusId(db: DbOrTx = this.db): Promise<string | null> {
    // Pilote : un seul campus (Annecy) ; le choix du campus viendra avec un second site.
    const [campus] = await db.select({ id: campuses.id }).from(campuses).orderBy(asc(campuses.name)).limit(1);
    return campus?.id ?? null;
  }

  async createUser(
    values: {
      email: string;
      firstName: string;
      lastName: string;
      passwordHash: string;
      campusId: string | null;
      reliabilityScore?: number;
      now: Date;
    },
    db: DbOrTx = this.db,
  ): Promise<string | null> {
    const [created] = await db
      .insert(users)
      .values({
        universityEmail: values.email,
        emailVerifiedAt: values.now,
        firstName: values.firstName,
        lastName: values.lastName,
        passwordHash: values.passwordHash,
        campusId: values.campusId,
        ...(values.reliabilityScore === undefined ? {} : { reliabilityScore: values.reliabilityScore.toFixed(3) }),
        createdAt: values.now,
      })
      .onConflictDoNothing({ target: users.universityEmail })
      .returning({ id: users.id });
    return created?.id ?? null;
  }

  async insertRefreshToken(
    values: { userId: string; familyId: string; tokenHash: string; expiresAt: Date; now: Date },
    db: DbOrTx = this.db,
  ): Promise<void> {
    await db.insert(refreshTokens).values({ ...values, createdAt: values.now });
  }

  async findRefreshToken(tokenHash: string, db: DbOrTx) {
    const [token] = await db
      .select()
      .from(refreshTokens)
      .where(eq(refreshTokens.tokenHash, tokenHash))
      .for('update');
    return token;
  }

  async markRefreshTokenUsed(id: string, now: Date, db: DbOrTx): Promise<void> {
    await db.update(refreshTokens).set({ usedAt: now }).where(eq(refreshTokens.id, id));
  }

  async revokeFamily(familyId: string, now: Date, db: DbOrTx = this.db): Promise<void> {
    await db
      .update(refreshTokens)
      .set({ revokedAt: now })
      .where(and(eq(refreshTokens.familyId, familyId), isNull(refreshTokens.revokedAt)));
  }

  async passwordHash(id: string): Promise<string | null> {
    const [user] = await this.db
      .select({ passwordHash: users.passwordHash })
      .from(users)
      .where(and(eq(users.id, id), isNull(users.deletedAt)));
    return user?.passwordHash ?? null;
  }

  async isActiveUser(id: string, db: DbOrTx = this.db): Promise<boolean> {
    const [user] = await db
      .select({ id: users.id })
      .from(users)
      .where(and(eq(users.id, id), isNull(users.deletedAt)));
    return Boolean(user);
  }
}
