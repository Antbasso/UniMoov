/**
 * Tarification (cahier §5) : fonctions pures, montants en centimes entiers.
 * Coût = consommation × distance × prix du carburant, partagé entre toutes les personnes
 * du véhicule, conducteur compris. Chaque passager ajoute la commission à sa part.
 */
export interface PriceInput {
  consumptionLPer100km: number;
  distanceM: number;
  fuelPriceCentsPerLitre: number;
  /** Personnes dans la voiture, conducteur compris (au moins 1). */
  persons: number;
  commissionCentsPerPassenger: number;
}

export interface PriceEstimate {
  totalCostCents: number;
  persons: number;
  /** Part de chacun, arrondie au centime supérieur : le conducteur n'est jamais perdant. */
  shareCents: number;
  commissionCents: number;
  /** Ce que paie chaque passager : sa part plus la commission. */
  passengerPaysCents: number;
  /** Ce que reçoit le conducteur : la part de chaque passager. */
  driverReceivesCents: number;
}

export function estimatePrice(input: PriceInput): PriceEstimate {
  const { consumptionLPer100km, distanceM, fuelPriceCentsPerLitre, persons, commissionCentsPerPassenger } = input;
  if (!Number.isInteger(persons) || persons < 1) throw new RangeError('Au moins une personne');
  if (![consumptionLPer100km, distanceM, fuelPriceCentsPerLitre].every((v) => Number.isFinite(v) && v >= 0)) {
    throw new RangeError('Valeurs négatives ou invalides');
  }
  if (!Number.isInteger(commissionCentsPerPassenger) || commissionCentsPerPassenger < 0) {
    throw new RangeError('Commission invalide');
  }
  // Litres = conso × km / 100 ; on arrondit une seule fois, sur le total en centimes.
  const totalCostCents = Math.round((consumptionLPer100km * distanceM * fuelPriceCentsPerLitre) / 100_000);
  const shareCents = Math.ceil(totalCostCents / persons);
  const passengers = persons - 1;
  return {
    totalCostCents,
    persons,
    shareCents,
    commissionCents: commissionCentsPerPassenger,
    passengerPaysCents: shareCents + commissionCentsPerPassenger,
    driverReceivesCents: shareCents * passengers,
  };
}

export interface ProRataInput {
  consumptionLPer100km: number;
  fuelPriceCentsPerLitre: number;
  /** Longueur du trajet entier (conducteur). */
  distanceM: number;
  /**
   * Distance à bord de chaque passager, mesurée depuis le campus (aller : de sa prise en charge
   * au campus ; retour : du campus à sa dépose). `null` : tout le trajet.
   */
  onboardM: readonly (number | null)[];
  commissionCentsPerPassenger: number;
}

export interface ProRataPrice {
  totalCostCents: number;
  /** Part du carburant de chaque passager, dans l'ordre d'entrée, arrondie au centime supérieur. */
  sharesCents: number[];
  commissionCents: number;
  /** Ce que reçoit le conducteur : la somme des parts. */
  driverReceivesCents: number;
}

/**
 * Partage au prorata de la distance (cahier §5) : le coût de chaque portion de route est
 * partagé entre les personnes à bord sur cette portion, conducteur compris. Un passager pris
 * en cours de route ne paie que la portion qu'il fait. Seul, sur tout le trajet, il paie la
 * moitié du coût, comme avant.
 */
export function proRataPrice(input: ProRataInput): ProRataPrice {
  const { consumptionLPer100km, fuelPriceCentsPerLitre, distanceM, commissionCentsPerPassenger } = input;
  if (![consumptionLPer100km, distanceM, fuelPriceCentsPerLitre].every((v) => Number.isFinite(v) && v >= 0)) {
    throw new RangeError('Valeurs négatives ou invalides');
  }
  if (!Number.isInteger(commissionCentsPerPassenger) || commissionCentsPerPassenger < 0) {
    throw new RangeError('Commission invalide');
  }
  const totalCostCents = Math.round((consumptionLPer100km * distanceM * fuelPriceCentsPerLitre) / 100_000);
  const perMeter = distanceM === 0 ? 0 : totalCostCents / distanceM;
  const onboard = input.onboardM.map((d) => Math.min(Math.max(d ?? distanceM, 0), distanceM));
  // Portions entre deux points de montée (ou de descente), depuis le campus.
  const cuts = [0, ...new Set(onboard)].sort((a, b) => a - b);
  const shares = onboard.map(() => 0);
  for (let k = 1; k < cuts.length; k++) {
    const from = cuts[k - 1]!;
    const to = cuts[k]!;
    const aboard = onboard.map((d, i) => (d >= to ? i : -1)).filter((i) => i >= 0);
    const each = ((to - from) * perMeter) / (aboard.length + 1);
    for (const i of aboard) shares[i]! += each;
  }
  // Arrondi au centime supérieur (le conducteur n'est jamais perdant), sans dépasser le coût
  // pour un passager seul sur tout le trajet. Petite tolérance pour les erreurs de flottant.
  const sharesCents = shares.map((v) => Math.max(0, Math.ceil(v - 1e-9)));
  return {
    totalCostCents,
    sharesCents,
    commissionCents: commissionCentsPerPassenger,
    driverReceivesCents: sharesCents.reduce((a, b) => a + b, 0),
  };
}
