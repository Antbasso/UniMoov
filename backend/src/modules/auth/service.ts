import { randomUUID } from 'node:crypto';
import { hash, verify } from '@node-rs/argon2';
import type { MailProvider } from '../../shared/mail/mail-provider.js';
import { AppError } from '../../shared/errors.js';
import type { SettingsService } from '../settings/service.js';
import {
  addDays,
  addMinutes,
  checkCode,
  checkRefreshToken,
  generateCode,
  generateRefreshToken,
  hashCode,
  hashRefreshToken,
  isAllowedUniversityEmail,
  normalizeEmail,
} from './domain.js';
import { accountExistsMail, signupCodeMail } from './mail-templates.js';
import { AUTH_POLICY } from './policy.js';
import type { AuthRepo, DbOrTx } from './repo.js';
import type { TokensResponse } from './schema.js';

export interface AuthServiceDeps {
  repo: AuthRepo;
  mail: MailProvider;
  settings: SettingsService;
  clock: () => Date;
  secret: string;
  signAccessToken: (userId: string) => string;
}

const invalidCode = () => new AppError(400, 'code_invalid', 'Code incorrect ou expiré');
const invalidCredentials = () => new AppError(401, 'invalid_credentials', 'Mail ou mot de passe incorrect');
const invalidRefresh = () => new AppError(401, 'invalid_refresh_token', 'Session expirée');

export class AuthService {
  private dummyHash: Promise<string> | undefined;

  constructor(private readonly deps: AuthServiceDeps) {}

  /** Envoie un code ; réponse identique que le compte existe ou non (pas d'énumération). */
  async requestSignupCode(rawEmail: string): Promise<void> {
    const { repo, mail, settings, clock, secret } = this.deps;
    const email = normalizeEmail(rawEmail);
    if (!isAllowedUniversityEmail(email, await settings.get('auth.allowedEmailDomains'))) {
      throw new AppError(400, 'email_domain_not_allowed', 'Utilise ton adresse mail universitaire');
    }
    const now = clock();
    const last = await repo.latestCode(email);
    if (last && now.getTime() - last.createdAt.getTime() < AUTH_POLICY.codeResendCooldownSeconds * 1000) {
      throw new AppError(429, 'code_cooldown', 'Attends une minute avant de redemander un code');
    }

    const existing = await repo.findUserByEmail(email);
    if (existing) {
      await mail.send(accountExistsMail(email));
      // Trace le délai d'attente comme pour un vrai code, sans code utilisable.
      await repo.replaceCode(email, 'none', now, now);
      return;
    }
    const code = generateCode();
    await repo.replaceCode(email, hashCode(secret, email, code), now, addMinutes(now, AUTH_POLICY.codeTtlMinutes));
    await mail.send(signupCodeMail(email, code));
  }

  async verifySignup(input: {
    universityEmail: string;
    code: string;
    firstName: string;
    lastName: string;
    password: string;
  }): Promise<TokensResponse> {
    const { repo, clock, secret } = this.deps;
    const email = normalizeEmail(input.universityEmail);
    const now = clock();

    const userId = await repo.transaction(async (tx) => {
      const stored = await repo.latestCode(email, tx);
      const result = checkCode(stored, hashCode(secret, email, input.code), now);
      if (result !== 'ok') {
        if (stored && result === 'invalid' && !stored.consumedAt) {
          await repo.incrementAttempts(stored.id, tx);
        }
        return null;
      }
      // Hachage (volontairement coûteux) seulement après un code valide : un essai faux ne
      // coûte rien au serveur.
      const passwordHash = await hash(input.password);
      await repo.consumeCode(stored!.id, now, tx);
      const id = await repo.createUser(
        {
          email,
          firstName: input.firstName,
          lastName: input.lastName,
          passwordHash,
          campusId: await repo.defaultCampusId(tx),
          now,
        },
        tx,
      );
      if (!id) throw new AppError(409, 'account_exists', 'Un compte existe déjà avec cette adresse');
      return id;
    });
    if (!userId) throw invalidCode();
    return this.issueTokens(userId, randomUUID());
  }

  async login(input: { universityEmail: string; password: string }): Promise<TokensResponse> {
    const user = await this.deps.repo.findUserByEmail(normalizeEmail(input.universityEmail));
    if (!user?.passwordHash || user.deletedAt) {
      // Même coût de calcul qu'un vrai essai : la durée ne révèle pas si le compte existe.
      await verify(await this.getDummyHash(), input.password);
      throw invalidCredentials();
    }
    if (!(await verify(user.passwordHash, input.password))) throw invalidCredentials();
    return this.issueTokens(user.id, randomUUID());
  }

  /** Rotation : chaque jeton ne sert qu'une fois ; une réutilisation révoque toute la famille. */
  async refresh(refreshToken: string): Promise<TokensResponse> {
    const { repo, clock } = this.deps;
    const now = clock();
    const outcome = await repo.transaction(async (tx) => {
      const stored = await repo.findRefreshToken(hashRefreshToken(refreshToken), tx);
      const check = checkRefreshToken(stored, now);
      if (check === 'reused') await repo.revokeFamily(stored!.familyId, now, tx);
      if (check !== 'ok' || !(await repo.isActiveUser(stored!.userId, tx))) return null;
      await repo.markRefreshTokenUsed(stored!.id, now, tx);
      return this.issueTokens(stored!.userId, stored!.familyId, tx);
    });
    if (!outcome) throw invalidRefresh();
    return outcome;
  }

  /** Révoque la session (famille du jeton) ; sans effet si le jeton est inconnu. */
  async logout(refreshToken: string): Promise<void> {
    const { repo, clock } = this.deps;
    await repo.transaction(async (tx) => {
      const stored = await repo.findRefreshToken(hashRefreshToken(refreshToken), tx);
      if (stored) await repo.revokeFamily(stored.familyId, clock(), tx);
    });
  }

  private async issueTokens(userId: string, familyId: string, db?: DbOrTx): Promise<TokensResponse> {
    const now = this.deps.clock();
    const refreshToken = generateRefreshToken();
    await this.deps.repo.insertRefreshToken(
      {
        userId,
        familyId,
        tokenHash: hashRefreshToken(refreshToken),
        expiresAt: addDays(now, AUTH_POLICY.refreshTokenTtlDays),
        now,
      },
      db,
    );
    return {
      accessToken: this.deps.signAccessToken(userId),
      refreshToken,
      accessTokenExpiresIn: AUTH_POLICY.accessTokenTtlSeconds,
    };
  }

  private getDummyHash(): Promise<string> {
    this.dummyHash ??= hash(generateRefreshToken());
    return this.dummyHash;
  }
}
