/**
 * Registre du portefeuille (cahier §5, AGENTS.md « Argent ») : fonctions pures qui
 * construisent des opérations équilibrées (la somme des écritures vaut zéro), en centimes.
 *
 * Comptes : `user:<id>` (disponible), `held:<id>` (retenu pour un trajet), `pending:<id>` (part
 * reçue, versée après le délai de signalement),
 * `platform:commission`, `provider:clearing` (contrepartie des fonds du prestataire).
 */
export type EntryKind =
  | 'topup'
  | 'hold'
  | 'hold_release'
  | 'ride_charge'
  | 'ride_credit'
  | 'commission'
  | 'payout'
  | 'refund';

export interface Entry {
  account: string;
  kind: EntryKind;
  amountCents: number;
}

export const userAccount = (id: string) => `user:${id}`;
export const heldAccount = (id: string) => `held:${id}`;
export const pendingAccount = (id: string) => `pending:${id}`;
export const COMMISSION = 'platform:commission';
export const CLEARING = 'provider:clearing';

function positive(amount: number, name: string): void {
  if (!Number.isInteger(amount) || amount <= 0) throw new RangeError(`${name} : entier positif attendu`);
}

export function isBalanced(entries: readonly Entry[]): boolean {
  return entries.reduce((sum, e) => sum + e.amountCents, 0) === 0;
}

/** Recharge confirmée par le prestataire. */
export function topupEntries(userId: string, amountCents: number): Entry[] {
  positive(amountCents, 'recharge');
  return [
    { account: CLEARING, kind: 'topup', amountCents: -amountCents },
    { account: userAccount(userId), kind: 'topup', amountCents },
  ];
}

/** Retenue au départ du trajet : prix estimé plus la marge. */
export function holdEntries(userId: string, amountCents: number): Entry[] {
  positive(amountCents, 'retenue');
  return [
    { account: userAccount(userId), kind: 'hold', amountCents: -amountCents },
    { account: heldAccount(userId), kind: 'hold', amountCents },
  ];
}

export function releaseEntries(userId: string, amountCents: number): Entry[] {
  positive(amountCents, 'libération');
  return [
    { account: heldAccount(userId), kind: 'hold_release', amountCents: -amountCents },
    { account: userAccount(userId), kind: 'hold_release', amountCents },
  ];
}

/**
 * Paiement d'un passager à la validation de sa présence : la retenue est libérée, puis le
 * passager paie sa part et la commission ; le conducteur reçoit la part, Uni-Moov la commission.
 */
export function chargeEntries(input: {
  passengerId: string;
  driverId: string;
  heldCents: number;
  shareCents: number;
  commissionCents: number;
}): Entry[] {
  const { passengerId, driverId, heldCents, shareCents, commissionCents } = input;
  if (!Number.isInteger(shareCents) || shareCents < 0) throw new RangeError('part invalide');
  if (!Number.isInteger(commissionCents) || commissionCents < 0) throw new RangeError('commission invalide');
  if (passengerId === driverId) throw new RangeError('le conducteur ne se paie pas lui-même');
  const entries: Entry[] = heldCents > 0 ? releaseEntries(passengerId, heldCents) : [];
  const total = shareCents + commissionCents;
  if (total > 0) entries.push({ account: userAccount(passengerId), kind: 'ride_charge', amountCents: -total });
  // La part attend le délai de signalement avant d'être disponible (`earningsReleaseEntries`).
  if (shareCents > 0) entries.push({ account: pendingAccount(driverId), kind: 'ride_credit', amountCents: shareCents });
  if (commissionCents > 0) entries.push({ account: COMMISSION, kind: 'commission', amountCents: commissionCents });
  return entries;
}

/** Délai de signalement passé, sans litige : la part du conducteur devient disponible. */
export function earningsReleaseEntries(driverId: string, shareCents: number): Entry[] {
  positive(shareCents, 'part');
  return [
    { account: pendingAccount(driverId), kind: 'ride_credit', amountCents: -shareCents },
    { account: userAccount(driverId), kind: 'ride_credit', amountCents: shareCents },
  ];
}

/** Retrait vers le compte bancaire du conducteur. */
export function payoutEntries(userId: string, amountCents: number): Entry[] {
  positive(amountCents, 'retrait');
  return [
    { account: userAccount(userId), kind: 'payout', amountCents: -amountCents },
    { account: CLEARING, kind: 'payout', amountCents },
  ];
}

/** Retrait refusé par le prestataire après le débit : le solde est recrédité. */
export function payoutReversalEntries(userId: string, amountCents: number): Entry[] {
  positive(amountCents, 'retrait annulé');
  return [
    { account: CLEARING, kind: 'refund', amountCents: -amountCents },
    { account: userAccount(userId), kind: 'refund', amountCents },
  ];
}

/** Retenue = prix estimé majoré de la marge, au centime supérieur. */
export function holdAmount(estimatedCents: number, marginPercent: number): number {
  if (!Number.isInteger(estimatedCents) || estimatedCents < 0) throw new RangeError('prix invalide');
  if (!Number.isFinite(marginPercent) || marginPercent < 0) throw new RangeError('marge invalide');
  return Math.ceil((estimatedCents * (100 + marginPercent)) / 100);
}

/** IBAN sans espaces, en majuscules. */
export function normalizeIban(raw: string): string {
  return raw.replace(/\s+/g, '').toUpperCase();
}

/** Contrôle ISO 13616 : format, longueur et clé (modulo 97). */
export function isValidIban(iban: string): boolean {
  if (!/^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$/.test(iban)) return false;
  const rearranged = iban.slice(4) + iban.slice(0, 4);
  let remainder = 0;
  for (const char of rearranged) {
    const digits = /\d/.test(char) ? char : String(char.charCodeAt(0) - 55);
    for (const d of digits) remainder = (remainder * 10 + Number(d)) % 97;
  }
  return remainder === 1;
}
