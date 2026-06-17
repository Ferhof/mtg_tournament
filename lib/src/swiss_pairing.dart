import 'dart:math';

import 'models.dart';
import 'standings.dart';

/// Generates Swiss pairings for the next round.
///
/// Approach:
///   * Round 1 is paired randomly.
///   * Later rounds order players by current standings (best first) and pair
///     adjacent players, using backtracking to avoid rematches.
///   * With an odd field, a bye is given to the lowest-standing player who has
///     received the fewest byes so far.
///
/// Note: this is the common "standings-order" Swiss pairing, which always
/// produces a valid no-rematch bracket when one exists. It is a simplification
/// of WotC's exact within-score-bracket fold; that refinement can be layered on
/// later without changing the data model.
class SwissPairing {
  static List<Match> pairNextRound({
    required List<Player> players,
    required List<Round> previousRounds,
    Random? random,
  }) {
    final rng = random ?? Random();
    final active = players.where((p) => !p.dropped).toList();

    final played = _playedPairs(previousRounds);
    final byeCounts = _byeCounts(previousRounds);

    final List<String> ordered;
    if (previousRounds.isEmpty) {
      active.shuffle(rng);
      ordered = active.map((p) => p.id).toList();
    } else {
      final standings = StandingsCalculator.compute(players, previousRounds);
      final rankById = {for (final s in standings) s.player.id: s.rank};
      active.sort((a, b) =>
          (rankById[a.id] ?? 1 << 30).compareTo(rankById[b.id] ?? 1 << 30));
      ordered = active.map((p) => p.id).toList();
    }

    final matches = <Match>[];

    if (ordered.length.isOdd) {
      final byeId =
          _chooseBye(ordered, byeCounts, previousRounds.isEmpty, rng);
      ordered.remove(byeId);
      matches.add(Match.bye(byeId));
    }

    final pairs = <List<String>>[];
    if (!_backtrack(ordered, played, pairs)) {
      // No rematch-free pairing exists: fall back to sequential pairing.
      pairs.clear();
      for (var i = 0; i + 1 < ordered.length; i += 2) {
        pairs.add([ordered[i], ordered[i + 1]]);
      }
    }

    for (final pair in pairs) {
      matches.add(Match.pairing(pair[0], pair[1]));
    }
    return matches;
  }

  /// Recursively pairs [remaining] (best→worst) avoiding any pair in [played].
  static bool _backtrack(
    List<String> remaining,
    Set<String> played,
    List<List<String>> out,
  ) {
    if (remaining.isEmpty) return true;
    final first = remaining.first;
    for (var i = 1; i < remaining.length; i++) {
      final cand = remaining[i];
      if (played.contains(_key(first, cand))) continue;
      out.add([first, cand]);
      final rest = [
        for (var j = 1; j < remaining.length; j++)
          if (j != i) remaining[j],
      ];
      if (_backtrack(rest, played, out)) return true;
      out.removeLast();
    }
    return false;
  }

  /// Bye goes to the lowest-standing player with the fewest prior byes.
  static String _chooseBye(
    List<String> ordered,
    Map<String, int> byeCounts,
    bool firstRound,
    Random rng,
  ) {
    if (firstRound) {
      return ordered[rng.nextInt(ordered.length)];
    }
    final worstFirst = ordered.reversed.toList();
    final minByes = worstFirst
        .map((id) => byeCounts[id] ?? 0)
        .reduce((a, b) => a < b ? a : b);
    for (final id in worstFirst) {
      if ((byeCounts[id] ?? 0) == minByes) return id;
    }
    return worstFirst.first;
  }

  static Set<String> _playedPairs(List<Round> rounds) {
    final s = <String>{};
    for (final r in rounds) {
      for (final m in r.matches) {
        if (!m.isBye && m.player2Id != null) {
          s.add(_key(m.player1Id, m.player2Id!));
        }
      }
    }
    return s;
  }

  static Map<String, int> _byeCounts(List<Round> rounds) {
    final counts = <String, int>{};
    for (final r in rounds) {
      for (final m in r.matches) {
        if (m.isBye) {
          counts[m.player1Id] = (counts[m.player1Id] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Order-independent key for a pair of players.
  static String _key(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
}
