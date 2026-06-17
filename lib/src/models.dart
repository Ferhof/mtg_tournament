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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dropped': dropped,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        dropped: json['dropped'] as bool? ?? false,
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

  Map<String, dynamic> toJson() => {
        'player1GameWins': player1GameWins,
        'player2GameWins': player2GameWins,
        'gameDraws': gameDraws,
      };

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
        player1GameWins: json['player1GameWins'] as int,
        player2GameWins: json['player2GameWins'] as int,
        gameDraws: json['gameDraws'] as int? ?? 0,
      );

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

  Map<String, dynamic> toJson() => {
        'player1Id': player1Id,
        'player2Id': player2Id,
        'isBye': isBye,
        'result': result?.toJson(),
      };

  factory Match.fromJson(Map<String, dynamic> json) => Match._(
        player1Id: json['player1Id'] as String,
        player2Id: json['player2Id'] as String?,
        isBye: json['isBye'] as bool,
        result: json['result'] == null
            ? null
            : MatchResult.fromJson(
                (json['result'] as Map).cast<String, dynamic>()),
      );

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

  Map<String, dynamic> toJson() => {
        'number': number,
        'matches': [for (final m in matches) m.toJson()],
      };

  factory Round.fromJson(Map<String, dynamic> json) => Round(
        number: json['number'] as int,
        matches: [
          for (final m in (json['matches'] as List))
            Match.fromJson((m as Map).cast<String, dynamic>()),
        ],
      );

  @override
  String toString() => 'Round $number (${matches.length} matches)';
}
