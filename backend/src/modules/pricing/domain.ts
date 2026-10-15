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
