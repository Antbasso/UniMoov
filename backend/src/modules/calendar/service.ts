import { AppError } from '../../shared/errors.js';
import type { SecretBox } from '../../shared/crypto.js';
import { FetchFailedError, UnsafeUrlError, normalizeCalendarUrl } from '../../shared/safe-fetch.js';
import { addDaysIso, parisDateOf, parisToUtc } from '../../shared/time.js';
import type { SettingsService } from '../settings/service.js';
import { changedDays, type ManualDay, manualSlots } from './domain.js';
import { daySlotsFromIntervals, InvalidCalendarError, parseIcsIntervals } from './ics.js';
import type { CalendarRepo } from './repo.js';

export interface CalendarServiceDeps {
  repo: CalendarRepo;
  box: SecretBox;
  /** Téléchargement d'un lien ICS (protégé contre le SSRF en production). */
  fetchIcs: (url: string) => Promise<string>;
  settings: SettingsService;
  clock: () => Date;
  /** Relance du matching pour les jours dont l'horaire a changé (cahier §3). */
  onScheduleChanged: (userId: string, days: string[]) => Promise<void>;
}

export interface ConnectionView {
  id: string;
  provider: string;
  consentedAt: Date;
  lastSyncedAt: Date | null;
  lastError: string | null;
}

const view = (c: ConnectionView): ConnectionView => ({
  id: c.id,
  provider: c.provider,
  consentedAt: c.consentedAt,
  lastSyncedAt: c.lastSyncedAt,
  lastError: c.lastError,
});

export class CalendarService {
  constructor(private readonly deps: CalendarServiceDeps) {}

  private async horizon(): Promise<{ from: string; to: string }> {
    const from = parisDateOf(this.deps.clock());
    return { from, to: addDaysIso(from, await this.deps.settings.get('calendar.horizonDays')) };
  }

  /** Lit l'agenda et n'en garde que le début et la fin de chaque journée. */
  private async readCalendar(url: string, from: string, to: string) {
    let text: string;
    try {
      text = await this.deps.fetchIcs(url);
    } catch (error) {
      if (error instanceof UnsafeUrlError) throw new AppError(400, 'calendar_url_invalid', 'Lien d’agenda invalide');
      if (error instanceof FetchFailedError) {
        throw new AppError(422, 'calendar_unreachable', 'Impossible de lire ton agenda');
      }
      throw error;
    }
    try {
      const intervals = parseIcsIntervals(text, parisToUtc(from, '00:00'), parisToUtc(to, '00:00'));
      return daySlotsFromIntervals(intervals);
    } catch (error) {
      if (error instanceof InvalidCalendarError) {
        throw new AppError(422, 'calendar_invalid', 'Ce lien ne renvoie pas un agenda');
      }
      throw error;
    }
  }

  /** Applique de nouveaux créneaux et relance le matching des jours modifiés. */
  private async apply(userId: string, change: () => Promise<void>): Promise<string[]> {
    const { from, to } = await this.horizon();
    const before = await this.deps.repo.effectiveSlots(userId, from, to);
    await change();
    const after = await this.deps.repo.effectiveSlots(userId, from, to);
    const days = changedDays(before, after);
    if (days.length > 0) await this.deps.onScheduleChanged(userId, days);
    return days;
  }

  /** Connexion d'un lien ICS, avec consentement explicite (AGENTS.md, RGPD). */
  async connectIcs(userId: string, rawUrl: string) {
    let url: string;
    try {
      url = normalizeCalendarUrl(rawUrl).href;
    } catch {
      throw new AppError(400, 'calendar_url_invalid', 'Lien d’agenda invalide');
    }
    const { from, to } = await this.horizon();
    // Lecture avant tout enregistrement : un lien inutilisable n'est pas conservé.
    const slots = await this.readCalendar(url, from, to);
    let connection!: ConnectionView;
    const days = await this.apply(userId, async () => {
      connection = await this.deps.repo.upsertConnection(userId, this.deps.box.seal(url), this.deps.clock());
      await this.deps.repo.replaceSlots(userId, 'calendar', from, to, slots);
    });
    return { connection: view(connection), changedDays: days };
  }

  async getConnection(userId: string): Promise<ConnectionView | null> {
    const connection = await this.deps.repo.findConnection(userId);
    return connection ? view(connection) : null;
  }

  async sync(userId: string) {
    const connection = await this.deps.repo.findConnection(userId);
    if (!connection?.encryptedCredentials) {
      throw new AppError(404, 'calendar_not_connected', 'Aucun agenda connecté');
    }
    const { from, to } = await this.horizon();
    let slots;
    try {
      slots = await this.readCalendar(this.deps.box.open(connection.encryptedCredentials), from, to);
    } catch (error) {
      if (error instanceof AppError) await this.deps.repo.markSync(userId, this.deps.clock(), error.code);
      throw error;
    }
    const days = await this.apply(userId, async () => {
      await this.deps.repo.replaceSlots(userId, 'calendar', from, to, slots);
      await this.deps.repo.markSync(userId, this.deps.clock(), null);
    });
    return { connection: view((await this.deps.repo.findConnection(userId))!), changedDays: days };
  }

  /** Révocation : lien et créneaux de l'agenda supprimés ; la semaine type reprend la main. */
  async disconnect(userId: string, connectionId: string): Promise<void> {
    let found = false;
    await this.apply(userId, async () => {
      found = await this.deps.repo.deleteConnection(userId, connectionId);
      if (found) await this.deps.repo.deleteSlots(userId, 'calendar');
    });
    if (!found) throw new AppError(404, 'not_found', 'Ressource introuvable');
  }

  getManual(userId: string) {
    return this.deps.repo.getManual(userId);
  }

  async setManual(userId: string, days: readonly ManualDay[]) {
    const weekdays = new Set(days.map((d) => d.weekday));
    if (weekdays.size !== days.length) throw new AppError(400, 'duplicate_weekday', 'Un même jour saisi deux fois');
    if (days.some((d) => d.endTime <= d.startTime)) {
      throw new AppError(400, 'invalid_schedule', 'La fin de journée doit suivre son début');
    }
    const { from, to } = await this.horizon();
    const changed = await this.apply(userId, async () => {
      await this.deps.repo.replaceManual(userId, days);
      await this.deps.repo.replaceSlots(userId, 'manual', from, to, manualSlots(days, from, Number(await this.deps.settings.get('calendar.horizonDays'))));
    });
    return { days: await this.deps.repo.getManual(userId), changedDays: changed };
  }

  async getSchedule(userId: string, from: string, to: string) {
    return this.deps.repo.effectiveSlots(userId, from, to);
  }

  /** Tâche quotidienne : resynchronise chaque agenda ; un échec n'arrête pas les autres. */
  async syncAll(): Promise<{ ok: number; failed: number }> {
    let ok = 0;
    let failed = 0;
    for (const connection of await this.deps.repo.listConnections()) {
      try {
        await this.sync(connection.userId);
        ok++;
      } catch {
        failed++;
      }
    }
    return { ok, failed };
  }

  /** Tâche hebdomadaire : prolonge les semaines types sur l'horizon glissant. */
  async extendManualAll(): Promise<void> {
    const { from, to } = await this.horizon();
    const horizonDays = await this.deps.settings.get('calendar.horizonDays');
    for (const userId of await this.deps.repo.usersWithManual()) {
      const template = await this.deps.repo.getManual(userId);
      await this.apply(userId, () => this.deps.repo.replaceSlots(userId, 'manual', from, to, manualSlots(template, from, horizonDays)));
    }
  }
}
