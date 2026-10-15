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

export type PauseRecurrence = 'weekly:2' | 'weekly:3' | 'weekly:4';

export interface Pause {
  startsOn: string; // AAAA-MM-JJ
  endsOn: string;
  recurrence: PauseRecurrence | null;
}

/** `weekly:N` : la pause s'applique une semaine sur N, à partir de la semaine de début. */
export function parseRecurrence(recurrence: string | null): number | null {
  if (recurrence === null) return null;
  const match = /^weekly:([2-4])$/.exec(recurrence);
  if (!match) throw new RangeError(`Récurrence invalide : ${recurrence}`);
  return Number(match[1]);
}

const DAY_MS = 86_400_000;

function toUtcDays(isoDate: string): number {
  const [y = Number.NaN, m = Number.NaN, d = Number.NaN] = isoDate.split('-').map(Number);
  return Date.UTC(y, m - 1, d) / DAY_MS;
}

/** Lundi de la semaine ISO, en jours depuis l'époque. */
function mondayOf(days: number): number {
  const weekday = (new Date(days * DAY_MS).getUTCDay() + 6) % 7; // lundi = 0
  return days - weekday;
}

export function isPauseActiveOn(pause: Pause, isoDate: string): boolean {
  const day = toUtcDays(isoDate);
  if (day < toUtcDays(pause.startsOn) || day > toUtcDays(pause.endsOn)) return false;
  const every = parseRecurrence(pause.recurrence);
  if (every === null) return true;
  const weeks = Math.round((mondayOf(day) - mondayOf(toUtcDays(pause.startsOn))) / 7);
  return weeks % every === 0;
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
