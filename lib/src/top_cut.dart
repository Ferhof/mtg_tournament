import 'models.dart';
import 'standings.dart';

/// Builds and advances a single-elimination top cut after the Swiss rounds.
///
/// Seeding follows the standard bracket so the two best seeds can only meet in
/// the final. Matches in each round are ordered so that the winners of adjacent
/// matches (0 vs 1, 2 vs 3, …) meet in the next round — that is exactly what
/// [nextRound] assumes.
class TopCut {
  /// Seed positions (1-based) per match for each supported bracket size.
  /// Each inner list is `[seedA, seedB]`; index in the outer list is the match
  /// order within the first playoff round.
  static const Map<int, List<List<int>>> _seedTable = {
    4: [
      [1, 4],
      [2, 3],
    ],
    8: [
      [1, 8],
      [4, 5],
      [2, 7],
      [3, 6],
    ],
  };

  /// Builds the first playoff round from final Swiss [standings].
  ///
  /// Takes the top [size] players (must be 4 or 8) by rank and pairs them by
  /// standard seeding. The returned round is numbered 1 (top-cut rounds are
  /// numbered independently of Swiss rounds).
  static Round seed(List<Standing> standings, int size) {
    final table = _seedTable[size];
    if (table == null) {
      throw ArgumentError('Unsupported top cut size: $size (expected 4 or 8).');
    }
    if (standings.length < size) {
      throw ArgumentError(
          'Not enough players for a top $size: only ${standings.length}.');
    }

    final sorted = [...standings]..sort((a, b) => a.rank.compareTo(b.rank));
    final bySeed = {for (var i = 0; i < size; i++) i + 1: sorted[i].player.id};

    final matches = [
      for (final pair in table) Match.pairing(bySeed[pair[0]]!, bySeed[pair[1]]!),
    ];
    return Round(number: 1, matches: matches);
  }

  /// Builds the next playoff round from the winners of [previous].
  ///
  /// Requires every match in [previous] to be reported. Pairs the winners of
  /// adjacent matches (0 vs 1, 2 vs 3, …). Throws if [previous] is the final
  /// (a single match) — use [championOf] for that.
  static Round nextRound(Round previous) {
    if (!previous.isComplete) {
      throw StateError('Cannot advance: round ${previous.number} is incomplete.');
    }
    if (previous.matches.length < 2) {
      throw StateError('The final round has no next round.');
    }
    final winners = [for (final m in previous.matches) _winnerId(m)];
    final matches = [
      for (var i = 0; i + 1 < winners.length; i += 2)
        Match.pairing(winners[i], winners[i + 1]),
    ];
    return Round(number: previous.number + 1, matches: matches);
  }

  /// The champion's player id, once [finalRound] (a single reported match) is
  /// decided. Returns `null` if the final is not a single completed match.
  static String? championOf(Round finalRound) {
    if (finalRound.matches.length != 1) return null;
    final m = finalRound.matches.single;
    if (!m.isReported) return null;
    return _winnerId(m);
  }

  static String _winnerId(Match m) {
    final r = m.result;
    if (r == null) {
      throw StateError('Match ${m.player1Id} vs ${m.player2Id} has no result.');
    }
    if (r.isDraw) {
      throw StateError('A single-elimination match cannot end in a draw.');
    }
    return r.player1Won ? m.player1Id : m.player2Id!;
  }
}
