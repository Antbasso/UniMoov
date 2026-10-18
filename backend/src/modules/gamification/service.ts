import { parisDateOf } from '../../shared/time.js';
import { badgesFor, co2SavedKg, levelFor, pointsFor, rank } from './domain.js';
import type { GamificationRepo } from './repo.js';

/** Taille du classement affiché (la place de la personne est toujours donnée). */
const LEADERBOARD_SIZE = 20;

function monthRange(today: string): { month: string; from: string; to: string } {
  const [y, m] = today.split('-').map(Number) as [number, number];
  const next = m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, '0')}`;
  const month = today.slice(0, 7);
  return { month, from: `${month}-01`, to: `${next}-01` };
}

/** Points, niveau, badges, impact et classement du campus (récompenses symboliques). */
export class GamificationService {
  constructor(
    private readonly repo: GamificationRepo,
    private readonly clock: () => Date,
  ) {}

  async achievements(userId: string) {
    const [stats] = await this.repo.stats({ userId });
    const s = stats!;
    const points = pointsFor(s);
    const { paidCents, receivedCents } = await this.repo.money(userId);
    const board = await this.leaderboard(userId);
    return {
      points,
      level: levelFor(points),
      badges: badgesFor(s),
      impact: {
        rides: s.ridesDriven + s.ridesAsPassenger,
        sharedKm: Math.round(s.sharedKm),
        co2SavedKg: co2SavedKg(s.sharedKm),
        paidCents,
        receivedCents,
      },
      month: { month: board.month, points: board.me?.points ?? 0, rank: board.me?.rank ?? null, ranked: board.ranked },
      leaderboardVisible: s.leaderboardVisible,
    };
  }

  /** Résumé public, pour le profil vu par une personne croisée : niveau, badges gagnés, CO₂. */
  async publicSummary(userId: string) {
    const [s] = await this.repo.stats({ userId });
    if (!s) return { level: { key: 'newcomer', points: 0 }, badges: [], co2SavedKg: 0 };
    const points = pointsFor(s);
    return {
      level: { key: levelFor(points).key, points },
      badges: badgesFor(s).filter((b) => b.earned).map((b) => b.key),
      co2SavedKg: co2SavedKg(s.sharedKm),
    };
  }

  /**
   * Classement du mois sur le campus : points des trajets du mois. Prénom et photo seulement
   * pour qui l'a accepté ; sinon la ligne est anonyme. Personne sans point : pas classé.
   */
  async leaderboard(userId: string) {
    const { month, from, to } = monthRange(parisDateOf(this.clock()));
    const campusId = await this.repo.campusOf(userId);
    const rows = campusId ? await this.repo.stats({ campusId }, { from, to }) : [];
    const ranked = rank(rows.map((r) => ({ ...r, points: pointsFor(r) })).filter((r) => r.points > 0));
    const view = (r: (typeof ranked)[number]) => {
      const me = r.userId === userId;
      const shown = me || r.leaderboardVisible;
      return {
        rank: r.rank,
        firstName: shown ? r.firstName : null,
        photoUrl: shown ? r.photoUrl : null,
        points: r.points,
        level: levelFor(r.points).key,
        me,
      };
    };
    const mine = ranked.find((r) => r.userId === userId);
    return {
      month,
      ranked: ranked.length,
      entries: ranked.slice(0, LEADERBOARD_SIZE).map(view),
      me: mine ? { rank: mine.rank, points: mine.points } : null,
    };
  }
}
