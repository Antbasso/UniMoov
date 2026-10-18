/** Règles pures du profil (cahier §1, §2, §12), testées unitairement. */

export const ONBOARDING_STEPS = ['profile', 'vehicle', 'preferences', 'calendar'] as const;
export type OnboardingStep = (typeof ONBOARDING_STEPS)[number];
export type StepStatus = 'done' | 'skipped';
export type OnboardingState = Partial<Record<OnboardingStep, StepStatus>>;

/** Première étape sans statut : l'utilisateur reprend là où il s'était arrêté. */
export function nextOnboardingStep(state: OnboardingState): OnboardingStep | null {
  return ONBOARDING_STEPS.find((step) => !state[step]) ?? null;
}

/**
 * Mode découverte tant que le profil ne permet pas le matching : adresse et campus requis
 * (cahier §1). Passer une étape ne suffit pas à en sortir.
 */
export function isDiscoveryMode(profile: { hasHome: boolean; campusId: string | null }): boolean {
  return !profile.hasHome || profile.campusId === null;
}

export type RoleMode = 'auto' | 'always_driver' | 'always_passenger';

/** Sans véhicule : passager uniquement, pas de mode automatique (cahier §2). */
export function isRoleModeAllowed(mode: RoleMode, hasVehicle: boolean): boolean {
  return hasVehicle || mode === 'always_passenger';
}

/**
 * Récurrence d'une pause, comme un événement d'agenda (cahier §12) :
 * - `weekly:N` : la première occurrence (startsOn → endsOn) revient toutes les N semaines ;
 * - `monthly:N` : elle revient tous les N mois, au même jour du mois ;
 * - `days:1,3` : chaque semaine, les jours ISO donnés (1 = lundi), de startsOn à repeatUntil.
 */
export type PauseRecurrence = string;

export interface Pause {
  startsOn: string; // AAAA-MM-JJ
  endsOn: string;
  recurrence: PauseRecurrence | null;
  /** Fin de la répétition (incluse), présente seulement avec une récurrence. */
  repeatUntil: string | null;
}

export type ParsedRecurrence =
  | { kind: 'weekly'; every: number }
  | { kind: 'monthly'; every: number }
  | { kind: 'days'; weekdays: number[] };

export function parseRecurrence(recurrence: string): ParsedRecurrence {
  const weekly = /^weekly:([1-8])$/.exec(recurrence);
  if (weekly) return { kind: 'weekly', every: Number(weekly[1]) };
  const monthly = /^monthly:([1-6])$/.exec(recurrence);
  if (monthly) return { kind: 'monthly', every: Number(monthly[1]) };
  const days = /^days:([1-7](?:,[1-7]){0,6})$/.exec(recurrence);
  if (days) {
    const weekdays = [...new Set(days[1]!.split(',').map(Number))].sort();
    return { kind: 'days', weekdays };
  }
  throw new RangeError(`Récurrence invalide : ${recurrence}`);
}

const DAY_MS = 86_400_000;

function toUtcDays(isoDate: string): number {
  const [y = Number.NaN, m = Number.NaN, d = Number.NaN] = isoDate.split('-').map(Number);
  return Date.UTC(y, m - 1, d) / DAY_MS;
}

/** Jour ISO de la semaine (1 = lundi). */
function isoWeekday(days: number): number {
  return ((new Date(days * DAY_MS).getUTCDay() + 6) % 7) + 1;
}

/** Même jour du mois `months` mois plus tard, ramené au dernier jour si le mois est plus court. */
function addMonths(days: number, months: number): number {
  const date = new Date(days * DAY_MS);
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + months;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return Date.UTC(year, month, Math.min(date.getUTCDate(), lastDay)) / DAY_MS;
}

export function isPauseActiveOn(pause: Pause, isoDate: string): boolean {
  const day = toUtcDays(isoDate);
  const start = toUtcDays(pause.startsOn);
  const length = toUtcDays(pause.endsOn) - start + 1;
  if (day < start) return false;
  if (pause.recurrence === null || pause.repeatUntil === null) return day < start + length;
  if (day > toUtcDays(pause.repeatUntil)) return false;
  const rule = parseRecurrence(pause.recurrence);
  switch (rule.kind) {
    case 'days':
      return rule.weekdays.includes(isoWeekday(day));
    case 'weekly':
      return (day - start) % (7 * rule.every) < length;
    case 'monthly':
      for (let k = 0; ; k += rule.every) {
        const occurrence = addMonths(start, k);
        if (occurrence > day) return false;
        if (day < occurrence + length) return true;
      }
  }
}

/** Règles d'une pause : plage valide, première occurrence plus courte que sa période, un an au plus. */
export function pauseProblem(pause: Pause): string | null {
  const start = toUtcDays(pause.startsOn);
  const length = toUtcDays(pause.endsOn) - start + 1;
  if (length < 1) return 'La fin de la pause précède son début';
  if ((pause.recurrence === null) !== (pause.repeatUntil === null)) {
    return 'Une pause répétée a une date de fin de répétition';
  }
  const last = pause.repeatUntil === null ? start + length - 1 : toUtcDays(pause.repeatUntil);
  if (last < start + length - 1) return 'La répétition s’arrête avant la fin de la première pause';
  if (last - start + 1 > 366) return 'Une pause dure au plus un an';
  if (pause.recurrence === null) return null;
  let rule: ParsedRecurrence;
  try {
    rule = parseRecurrence(pause.recurrence);
  } catch {
    return 'Récurrence inconnue';
  }
  if (rule.kind === 'weekly' && length > 7 * rule.every) return 'La pause est plus longue que sa période';
  if (rule.kind === 'monthly' && length > 28) return 'Une pause mensuelle dure au plus 28 jours';
  return null;
}

export function isPausedOn(pauses: readonly Pause[], isoDate: string): boolean {
  return pauses.some((pause) => isPauseActiveOn(pause, isoDate));
}

/** Durée d'une pause en jours, bornes incluses. */
export function pauseLengthDays(pause: Pick<Pause, 'startsOn' | 'endsOn'>): number {
  return toUtcDays(pause.endsOn) - toUtcDays(pause.startsOn) + 1;
}

/** Date du jour à Paris (AAAA-MM-JJ), base des règles de pause. */
export function parisDate(now: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Paris',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}
