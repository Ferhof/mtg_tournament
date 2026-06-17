/// Core data models for the tournament engine.
///
/// Everything here is immutable. State changes (reporting a result, dropping a
/// player) produce new objects rather than mutating in place — this keeps the
/// engine pure and makes standings always re-computable from raw history.
library;

/// A competitor in the tournament.
class Player {
  final String id;
  final String name;

  /// A dropped player keeps all past results but is not paired in future
  /// rounds. They still appear in the standings.
  final bool dropped;

  const Player({required this.id, required this.name, this.dropped = false});

  Player copyWith({String? name, bool? dropped}) => Player(
        id: id,
        name: name ?? this.name,
        dropped: dropped ?? this.dropped,
      );

  @override
  String toString() => 'Player($id, $name${dropped ? ', dropped' : ''})';
}

/// The reported game result of one match (usually best-of-three).
///
/// Counts are *games*, not matches. Example: a 2–1 win is
/// `MatchResult(player1GameWins: 2, player2GameWins: 1)`.
class MatchResult {
  final int player1GameWins;
  final int player2GameWins;
  final int gameDraws;

  const MatchResult({
    required this.player1GameWins,
    required this.player2GameWins,
    this.gameDraws = 0,
  })  : assert(player1GameWins >= 0),
        assert(player2GameWins >= 0),
        assert(gameDraws >= 0);

  bool get player1Won => player1GameWins > player2GameWins;
  bool get player2Won => player2GameWins > player1GameWins;
  bool get isDraw => player1GameWins == player2GameWins;

  @override
  String toString() => '$player1GameWins-$player2GameWins'
      '${gameDraws > 0 ? '-$gameDraws' : ''}';
}

/// A single pairing in a round. Either a normal match between two players, or a
/// bye granted to one player.
class Match {
  final String player1Id;

  /// `null` when this match is a bye.
  final String? player2Id;

  final bool isBye;

  /// `null` until a result is reported. Always `null` for a bye.
  final MatchResult? result;

  const Match._({
    required this.player1Id,
    required this.player2Id,
    required this.isBye,
    required this.result,
  });

  factory Match.pairing(String player1Id, String player2Id) => Match._(
        player1Id: player1Id,
        player2Id: player2Id,
        isBye: false,
        result: null,
      );

  factory Match.bye(String playerId) => Match._(
        player1Id: playerId,
        player2Id: null,
        isBye: true,
        result: null,
      );

  /// A bye is always considered reported (it has a fixed outcome).
  bool get isReported => isBye || result != null;

  bool involves(String playerId) =>
      player1Id == playerId || player2Id == playerId;

  /// Returns a copy of this match with [result] set. Throws for a bye.
  Match withResult(MatchResult r) {
    if (isBye) {
      throw StateError('Cannot report a result for a bye.');
    }
    return Match._(
      player1Id: player1Id,
      player2Id: player2Id,
      isBye: false,
      result: r,
    );
  }

  @override
  String toString() => isBye
      ? 'Bye($player1Id)'
      : 'Match($player1Id vs $player2Id'
          '${result != null ? ', $result' : ', pending'})';
}

/// A round is just a numbered list of matches.
class Round {
  final int number;
  final List<Match> matches;

  const Round({required this.number, required this.matches});

  bool get isComplete => matches.every((m) => m.isReported);

  @override
  String toString() => 'Round $number (${matches.length} matches)';
}
