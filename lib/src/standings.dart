import 'models.dart';

/// A single row in the standings table.
class Standing {
  final Player player;
  final int matchPoints;

  /// Match record (a bye counts as a win here).
  final int wins;
  final int losses;
  final int draws;

  /// Own match-win percentage (floored at [StandingsCalculator.minPercentage]).
  final double matchWinPct;

  /// Own game-win percentage (floored).
  final double gameWinPct;

  /// Opponents' match-win percentage (OMW%).
  final double oppMatchWinPct;

  /// Opponents' game-win percentage (OGW%).
  final double oppGameWinPct;

  /// 1-based position in the standings.
  final int rank;

  const Standing({
    required this.player,
    required this.matchPoints,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.matchWinPct,
    required this.gameWinPct,
    required this.oppMatchWinPct,
    required this.oppGameWinPct,
    required this.rank,
  });

  Standing copyWith({int? rank}) => Standing(
        player: player,
        matchPoints: matchPoints,
        wins: wins,
        losses: losses,
        draws: draws,
        matchWinPct: matchWinPct,
        gameWinPct: gameWinPct,
        oppMatchWinPct: oppMatchWinPct,
        oppGameWinPct: oppGameWinPct,
        rank: rank ?? this.rank,
      );

  @override
  String toString() => '#$rank ${player.name}  '
      '${matchPoints}pts  '
      'OMW ${(oppMatchWinPct * 100).toStringAsFixed(1)}%  '
      'GW ${(gameWinPct * 100).toStringAsFixed(1)}%  '
      'OGW ${(oppGameWinPct * 100).toStringAsFixed(1)}%';
}

/// Computes standings and tiebreakers from the raw round history.
///
/// Tiebreaker order follows the WotC Magic Tournament Rules, Appendix C:
///   1. Match points
///   2. Opponents' match-win percentage (OMW%)
///   3. Game-win percentage (GW%)
///   4. Opponents' game-win percentage (OGW%)
///
/// Byes are worth 3 match points but are excluded from every percentage
/// calculation, and a bye is never counted as an opponent.
class StandingsCalculator {
  /// The floor applied to any individual win-percentage (WotC uses 0.33).
  static const double minPercentage = 0.33;

  static List<Standing> compute(List<Player> players, List<Round> rounds) {
    final agg = <String, _Agg>{for (final p in players) p.id: _Agg()};

    for (final round in rounds) {
      for (final m in round.matches) {
        if (m.isBye) {
          final a = agg[m.player1Id];
          if (a != null) {
            a.matchPoints += 3;
            a.wins += 1;
            // Excluded from percentages and opponent lists.
          }
          continue;
        }
        if (!m.isReported) continue;

        final a1 = agg[m.player1Id];
        final a2 = agg[m.player2Id!];
        if (a1 == null || a2 == null) continue;
        final r = m.result!;

        a1.opponents.add(m.player2Id!);
        a2.opponents.add(m.player1Id);

        final totalGames = r.player1GameWins + r.player2GameWins + r.gameDraws;
        a1.gamePoints += r.player1GameWins * 3 + r.gameDraws;
        a2.gamePoints += r.player2GameWins * 3 + r.gameDraws;
        a1.gamesPlayed += totalGames;
        a2.gamesPlayed += totalGames;

        if (r.player1Won) {
          a1.matchPoints += 3;
          a1.wins += 1;
          a2.losses += 1;
          a1.pctMatchPoints += 3;
        } else if (r.player2Won) {
          a2.matchPoints += 3;
          a2.wins += 1;
          a1.losses += 1;
          a2.pctMatchPoints += 3;
        } else {
          a1.matchPoints += 1;
          a2.matchPoints += 1;
          a1.draws += 1;
          a2.draws += 1;
          a1.pctMatchPoints += 1;
          a2.pctMatchPoints += 1;
        }
        a1.pctMatches += 1;
        a2.pctMatches += 1;
      }
    }

    double mwp(String id) {
      final a = agg[id]!;
      if (a.pctMatches == 0) return 0.0;
      final v = a.pctMatchPoints / (3 * a.pctMatches);
      return v < minPercentage ? minPercentage : v;
    }

    double gwp(String id) {
      final a = agg[id]!;
      if (a.gamesPlayed == 0) return 0.0;
      final v = a.gamePoints / (3 * a.gamesPlayed);
      return v < minPercentage ? minPercentage : v;
    }

    final standings = <Standing>[];
    for (final p in players) {
      final a = agg[p.id]!;
      final opps = a.opponents;
      final omw = opps.isEmpty
          ? 0.0
          : opps.map(mwp).reduce((x, y) => x + y) / opps.length;
      final ogw = opps.isEmpty
          ? 0.0
          : opps.map(gwp).reduce((x, y) => x + y) / opps.length;

      standings.add(Standing(
        player: p,
        matchPoints: a.matchPoints,
        wins: a.wins,
        losses: a.losses,
        draws: a.draws,
        matchWinPct: mwp(p.id),
        gameWinPct: gwp(p.id),
        oppMatchWinPct: omw,
        oppGameWinPct: ogw,
        rank: 0,
      ));
    }

    standings.sort((x, y) {
      var c = y.matchPoints.compareTo(x.matchPoints);
      if (c != 0) return c;
      c = y.oppMatchWinPct.compareTo(x.oppMatchWinPct);
      if (c != 0) return c;
      c = y.gameWinPct.compareTo(x.gameWinPct);
      if (c != 0) return c;
      c = y.oppGameWinPct.compareTo(x.oppGameWinPct);
      if (c != 0) return c;
      return x.player.name.compareTo(y.player.name); // stable final fallback
    });

    return [
      for (var i = 0; i < standings.length; i++)
        standings[i].copyWith(rank: i + 1),
    ];
  }
}

/// Internal per-player accumulator.
class _Agg {
  int matchPoints = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;

  int gamePoints = 0;
  int gamesPlayed = 0;

  /// Match points / matches counted toward percentages (byes excluded).
  int pctMatchPoints = 0;
  int pctMatches = 0;

  /// Opponent ids actually played (byes excluded; duplicates kept on purpose).
  final List<String> opponents = [];
}
