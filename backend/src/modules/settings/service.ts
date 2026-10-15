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
