/** Jeu de données de développement : étudiants fictifs autour du campus d'Annecy. */
export const PILOT_CAMPUS_ID = '00000000-0000-4000-8000-000000000001';

/** Mot de passe des comptes de démonstration (développement uniquement). */
export const DEMO_PASSWORD = 'unimoov-demo';

export interface SeedUser {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  homeAddress: string;
  lat: number;
  lon: number;
  roleMode: 'auto' | 'always_driver' | 'always_passenger';
  vehicle?: { consumptionLPer100km: string; defaultSeats: number; maxDetourMinutes: number; model?: string; color?: string };
  /** Semaine type : jour ISO (1 = lundi) → début et fin de journée (heure de Paris). */
  week: Record<number, [string, string]>;
}

const id = (n: number) => `00000000-0000-4000-8000-1000000000${String(n).padStart(2, '0')}`;
/** Identifiant fixe du véhicule de l'étudiant n (distinct de celui de l'utilisateur). */
export const vehicleId = (userId: string) => userId.replace('-1000000000', '-2000000000');

const weekdays = (start: string, end: string, days = [1, 2, 3, 4, 5]) =>
  Object.fromEntries(days.map((d) => [d, [start, end] as [string, string]]));

// Adresses au niveau du quartier : aucune donnée réelle.
export const seedUsers: SeedUser[] = [
  {
    id: id(1), firstName: 'Léa', lastName: 'Martin', email: 'lea.martin@etu.univ-smb.fr',
    homeAddress: 'Centre, 74600 Seynod', lat: 45.8865, lon: 6.089, roleMode: 'auto',
    vehicle: { consumptionLPer100km: '5.8', defaultSeats: 3, maxDetourMinutes: 10, model: 'Renault Clio', color: 'grise' },
    week: weekdays('08:00', '17:00'),
  },
  {
    id: id(2), firstName: 'Hugo', lastName: 'Bernard', email: 'hugo.bernard@etu.univ-smb.fr',
    homeAddress: 'Centre, 74960 Cran-Gevrier', lat: 45.905, lon: 6.103, roleMode: 'always_passenger',
    week: weekdays('08:00', '17:00'),
  },
  {
    id: id(3), firstName: 'Chloé', lastName: 'Dubois', email: 'chloe.dubois@etu.univ-smb.fr',
    homeAddress: 'Centre, 74960 Meythet', lat: 45.918, lon: 6.096, roleMode: 'always_passenger',
    week: weekdays('08:15', '16:30'),
  },
  {
    id: id(4), firstName: 'Nathan', lastName: 'Petit', email: 'nathan.petit@etu.univ-smb.fr',
    homeAddress: 'Centre, 74320 Sévrier', lat: 45.864, lon: 6.141, roleMode: 'always_driver',
    vehicle: { consumptionLPer100km: '6.5', defaultSeats: 4, maxDetourMinutes: 12, model: 'Peugeot 308', color: 'bleue' },
    week: weekdays('08:00', '18:00'),
  },
  {
    id: id(5), firstName: 'Inès', lastName: 'Robert', email: 'ines.robert@etu.univ-smb.fr',
    homeAddress: 'Vieille ville, 74000 Annecy', lat: 45.8992, lon: 6.1294, roleMode: 'always_passenger',
    week: weekdays('08:00', '17:30', [1, 2, 3, 4]),
  },
  {
    id: id(6), firstName: 'Lucas', lastName: 'Moreau', email: 'lucas.moreau@etu.univ-smb.fr',
    homeAddress: 'Centre, 74150 Rumilly', lat: 45.8667, lon: 5.944, roleMode: 'auto',
    vehicle: { consumptionLPer100km: '5.2', defaultSeats: 2, maxDetourMinutes: 8, model: 'Toyota Yaris', color: 'blanche' },
    week: weekdays('08:00', '17:00'),
  },
  {
    id: id(7), firstName: 'Manon', lastName: 'Laurent', email: 'manon.laurent@etu.univ-smb.fr',
    homeAddress: 'Centre, 74370 Argonay', lat: 45.942, lon: 6.142, roleMode: 'always_passenger',
    week: weekdays('08:30', '17:00'),
  },
  {
    id: id(8), firstName: 'Théo', lastName: 'Simon', email: 'theo.simon@etu.univ-smb.fr',
    homeAddress: 'Centre, 74370 Pringy', lat: 45.948, lon: 6.123, roleMode: 'always_passenger',
    // Cours plus tard le lundi : aucune voiture à cette heure-là.
    week: { ...weekdays('08:00', '17:00'), 1: ['10:00', '18:00'] },
  },
];
