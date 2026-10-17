import { eq } from 'drizzle-orm';
import { z } from 'zod';
import type { Db } from '../../db/client.js';
import { appSettings } from '../../db/schema.js';

/** Paramètres connus et leur forme. Les valeurs vivent dans `app_settings` (jamais en dur). */
const settingSchemas = {
  'auth.allowedEmailDomains': z.array(z.string().min(3)).min(1),
  'matching.roadFactor': z.number().min(1).max(3),
  'matching.avgSpeedKmh': z.number().min(5).max(130),
  'matching.arrivalWindowMinutes': z.number().int().min(0).max(180),
  'calendar.horizonDays': z.number().int().min(1).max(90),
  'search.dailyQuota': z.number().int().min(1).max(1000),
  'pricing.fuelPriceCentsPerLitre': z.number().int().min(1).max(1000),
  'pricing.commissionCentsPerPassenger': z.number().int().min(0).max(500),
  'rides.meetingPointMaxMeters': z.number().int().min(100).max(20_000),
  'rides.startWindowMinutes': z.number().int().min(0).max(24 * 60),
  'rides.staleAfterHours': z.number().int().min(1).max(72),
  'wallet.minTopupCents': z.number().int().min(1).max(100_000),
  'wallet.holdMarginPercent': z.number().min(0).max(100),
  'tracking.presenceRadiusMeters': z.number().int().min(10).max(2000),
  'tracking.arrivalRadiusMeters': z.number().int().min(10).max(5000),
  'tracking.traceRetentionDays': z.number().int().min(1).max(365),
  'reliability.prior': z.number().min(0).max(1),
  'reliability.priorWeight': z.number().min(0).max(100),
  'reliability.ratingShare': z.number().min(0).max(1),
  'reliability.windowDays': z.number().int().min(7).max(730),
  'reliability.penalties': z
    .object({
      earlyHours: z.number().min(0).max(168),
      lateHours: z.number().min(0).max(168),
      early: z.number().min(0).max(5),
      medium: z.number().min(0).max(5),
      late: z.number().min(0).max(5),
      noShow: z.number().min(0).max(5),
    })
    .refine((p) => p.lateHours <= p.earlyHours, 'lateHours doit être inférieur à earlyHours'),
  'matching.reliabilityWeightSeconds': z.number().int().min(0).max(3600),
  'ratings.windowDays': z.number().int().min(1).max(60),
  'disputes.windowDays': z.number().int().min(1).max(90),
  'reports.dailyLimit': z.number().int().min(1).max(100),
  'support.email': z.email(),
  'chat.rideArchiveDays': z.number().int().min(1).max(90),
  'chat.rideDeleteDays': z.number().int().min(1).max(365),
  'chat.maxGroupMembers': z.number().int().min(3).max(50),
  'notifications.reminderMinutes': z.number().int().min(5).max(24 * 60),
} as const;

type SettingKey = keyof typeof settingSchemas;
type SettingValue<K extends SettingKey> = z.infer<(typeof settingSchemas)[K]>;

export class SettingsService {
  private readonly cache = new Map<string, { value: unknown; expiresAt: number }>();

  constructor(
    private readonly db: Db,
    private readonly ttlMs = 60_000,
    private readonly now: () => number = Date.now,
  ) {}

  async get<K extends SettingKey>(key: K): Promise<SettingValue<K>> {
    const hit = this.cache.get(key);
    if (hit && hit.expiresAt > this.now()) return hit.value as SettingValue<K>;
    const [row] = await this.db.select().from(appSettings).where(eq(appSettings.key, key));
    if (!row) throw new Error(`Paramètre manquant : ${key}`);
    const value = settingSchemas[key].parse(row.value) as SettingValue<K>;
    this.cache.set(key, { value, expiresAt: this.now() + this.ttlMs });
    return value;
  }
}
