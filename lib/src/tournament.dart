import 'dart:math';

import 'models.dart';

/// Lifecycle of a tournament.
enum TournamentStatus {
  /// Players are being registered; the bracket has not started yet.
  registering,

  /// Swiss rounds are in progress.
  swiss,

  /// Single-elimination top cut is in progress.
  topCut,

  /// The tournament is over (a champion is decided, or there is no top cut).
  finished;

  String toJson() => name;

  static TournamentStatus fromJson(String value) =>
      TournamentStatus.values.firstWhere((s) => s.name == value);
}

/// Static configuration chosen before a tournament starts.
class TournamentConfig {
  final String name;

  /// Number of Swiss rounds to play.
  final int swissRounds;

  /// Games needed to win a match (best-of-[bestOf]); 3 means best-of-three.
  final int bestOf;

  /// Size of the single-elimination top cut: 0 (none), 4 or 8.
  final int topCutSize;

  const TournamentConfig({
    required this.name,
    required this.swissRounds,
    this.bestOf = 3,
    this.topCutSize = 0,
  });

  TournamentConfig copyWith({
    String? name,
    int? swissRounds,
    int? bestOf,
    int? topCutSize,
  }) =>
      TournamentConfig(
        name: name ?? this.name,
        swissRounds: swissRounds ?? this.swissRounds,
        bestOf: bestOf ?? this.bestOf,
        topCutSize: topCutSize ?? this.topCutSize,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'swissRounds': swissRounds,
        'bestOf': bestOf,
        'topCutSize': topCutSize,
      };

  factory TournamentConfig.fromJson(Map<String, dynamic> json) =>
      TournamentConfig(
        name: json['name'] as String,
        swissRounds: json['swissRounds'] as int,
        bestOf: json['bestOf'] as int? ?? 3,
        topCutSize: json['topCutSize'] as int? ?? 0,
      );
}

/// The full state of one tournament: the single aggregate the app persists.
///
/// Immutable like the rest of the engine — every mutation returns a new
/// [Tournament] via [copyWith], so the whole object can be serialized and
/// restored verbatim and standings stay re-computable from the raw rounds.
class Tournament {
  final String id;
  final TournamentConfig config;
  final List<Player> players;

  /// Completed and in-progress Swiss rounds, in order.
  final List<Round> swissRounds;

  /// Single-elimination rounds, in order (empty until the top cut starts).
  final List<Round> topCutRounds;

  final TournamentStatus status;

  const Tournament({
    required this.id,
    required this.config,
    required this.players,
    this.swissRounds = const [],
    this.topCutRounds = const [],
    this.status = TournamentStatus.registering,
  });

  Tournament copyWith({
    TournamentConfig? config,
    List<Player>? players,
    List<Round>? swissRounds,
    List<Round>? topCutRounds,
    TournamentStatus? status,
  }) =>
      Tournament(
        id: id,
        config: config ?? this.config,
        players: players ?? this.players,
        swissRounds: swissRounds ?? this.swissRounds,
        topCutRounds: topCutRounds ?? this.topCutRounds,
        status: status ?? this.status,
      );

  Player? playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'players': [for (final p in players) p.toJson()],
        'swissRounds': [for (final r in swissRounds) r.toJson()],
        'topCutRounds': [for (final r in topCutRounds) r.toJson()],
        'status': status.toJson(),
      };

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as String,
        config:
            TournamentConfig.fromJson((json['config'] as Map).cast<String, dynamic>()),
        players: [
          for (final p in (json['players'] as List))
            Player.fromJson((p as Map).cast<String, dynamic>()),
        ],
        swissRounds: [
          for (final r in (json['swissRounds'] as List? ?? []))
            Round.fromJson((r as Map).cast<String, dynamic>()),
        ],
        topCutRounds: [
          for (final r in (json['topCutRounds'] as List? ?? []))
            Round.fromJson((r as Map).cast<String, dynamic>()),
        ],
        status: TournamentStatus.fromJson(json['status'] as String),
      );
}

/// Recommended number of Swiss rounds for a given field size.
///
/// Uses the common `ceil(log2(n))` heuristic (e.g. 8 players → 3 rounds,
/// 16 → 4, 9–16 → 4). Returns at least 1 for any field of 2 or more.
int recommendedSwissRounds(int playerCount) {
  if (playerCount < 2) return 0;
  return max(1, (log(playerCount) / log(2)).ceil());
}
