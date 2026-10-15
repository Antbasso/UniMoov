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

  async isActiveUser(id: string, db: DbOrTx = this.db): Promise<boolean> {
    const [user] = await db
      .select({ id: users.id })
      .from(users)
      .where(and(eq(users.id, id), isNull(users.deletedAt)));
    return Boolean(user);
  }
}
