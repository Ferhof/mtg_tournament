import 'package:flutter/foundation.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';
import 'package:uuid/uuid.dart';

import '../data/player_roster_repository.dart';
import '../data/tournament_repository.dart';

/// Holds the current [Tournament] and exposes every mutation the UI needs.
///
/// Each mutation produces a new immutable [Tournament] (engine invariant),
/// notifies listeners, and autosaves to disk. Standings are always recomputed
/// from raw rounds via [StandingsCalculator] — nothing is cached.
class TournamentController extends ChangeNotifier {
  TournamentController(this._repo, this._rosterRepo);

  final TournamentRepository _repo;
  final PlayerRosterRepository _rosterRepo;
  final _uuid = const Uuid();

  Tournament? _tournament;
  Tournament? get tournament => _tournament;

  List<String> _rosterNames = const [];

  /// Names of everyone ever added to a tournament, for quick re-adding.
  List<String> get rosterNames => _rosterNames;

  bool _loading = true;
  bool get loading => _loading;

  /// Loads any saved tournament and the player roster on startup.
  Future<void> init() async {
    _tournament = await _repo.load();
    _rosterNames = await _rosterRepo.load();
    _loading = false;
    notifyListeners();
  }

  Future<void> _commit(Tournament next) async {
    _tournament = next;
    notifyListeners();
    await _repo.save(next);
  }

  // --- Setup ---------------------------------------------------------------

  /// Creates a fresh tournament in the registering state.
  Future<void> createTournament(String name) async {
    await _commit(Tournament(
      id: _uuid.v4(),
      config: TournamentConfig(name: name.trim().isEmpty ? 'Tournament' : name.trim(), swissRounds: 0),
      players: const [],
    ));
  }

  /// Discards the current tournament and its save file.
  Future<void> reset() async {
    await _repo.clear();
    _tournament = null;
    notifyListeners();
  }

  Future<void> addPlayer(String name) async {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final player = Player(id: _uuid.v4(), name: trimmed);
    await _commit(t.copyWith(players: [...t.players, player]));
    await _addToRoster(trimmed);
  }

  Future<void> removePlayer(String playerId) async {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return;
    await _commit(t.copyWith(
      players: t.players.where((p) => p.id != playerId).toList(),
      // Drop any manual pairing/bye that referenced the removed player.
      manualFirstRound:
          t.manualFirstRound.where((m) => !m.involves(playerId)).toList(),
    ));
  }

  // --- Roster --------------------------------------------------------------

  Future<void> _addToRoster(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_rosterNames.any((n) => n.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    _rosterNames = [..._rosterNames, trimmed]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    notifyListeners();
    await _rosterRepo.save(_rosterNames);
  }

  /// Removes [name] from the roster of known players (does not touch the current
  /// tournament's players).
  Future<void> removeFromRoster(String name) async {
    _rosterNames =
        _rosterNames.where((n) => n.toLowerCase() != name.toLowerCase()).toList();
    notifyListeners();
    await _rosterRepo.save(_rosterNames);
  }

  /// Corrects a misspelled name in the roster. Rejects empty names and names
  /// that collide with a different existing entry.
  Future<void> renameInRoster(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final collides = _rosterNames.any((n) =>
        n.toLowerCase() == trimmed.toLowerCase() &&
        n.toLowerCase() != oldName.toLowerCase());
    if (collides) return;
    _rosterNames = [
      for (final n in _rosterNames)
        if (n.toLowerCase() == oldName.toLowerCase()) trimmed else n,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    notifyListeners();
    await _rosterRepo.save(_rosterNames);
  }

  Future<void> updateConfig({int? swissRounds, int? bestOf, int? topCutSize, String? name}) async {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return;
    await _commit(t.copyWith(
      config: t.config.copyWith(
        swissRounds: swissRounds,
        bestOf: bestOf,
        topCutSize: topCutSize,
        name: name,
      ),
    ));
  }

  // --- Manual first-round pairings -----------------------------------------

  /// Active players not yet placed in a manual first-round pairing or bye.
  List<Player> get unpairedPlayers {
    final t = _tournament;
    if (t == null) return const [];
    final taken = <String>{};
    for (final m in t.manualFirstRound) {
      taken.add(m.player1Id);
      if (m.player2Id != null) taken.add(m.player2Id!);
    }
    return t.players
        .where((p) => !p.dropped && !taken.contains(p.id))
        .toList();
  }

  Future<void> addManualPairing(String player1Id, String player2Id) async {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return;
    if (player1Id == player2Id) return;
    await _commit(t.copyWith(
      manualFirstRound: [
        ...t.manualFirstRound,
        Match.pairing(player1Id, player2Id),
      ],
    ));
  }

  /// A manual first-round bye is only valid when the active field is odd
  /// (Swiss awards exactly one bye) and no bye has been arranged yet.
  bool get canAddManualBye {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return false;
    final activeCount = t.players.where((p) => !p.dropped).length;
    if (activeCount.isEven) return false;
    if (t.manualFirstRound.any((m) => m.isBye)) return false;
    return unpairedPlayers.isNotEmpty;
  }

  Future<void> addManualBye(String playerId) async {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return;
    if (!canAddManualBye) return;
    await _commit(t.copyWith(
      manualFirstRound: [...t.manualFirstRound, Match.bye(playerId)],
    ));
  }

  Future<void> removeManualMatch(int index) async {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return;
    if (index < 0 || index >= t.manualFirstRound.length) return;
    await _commit(t.copyWith(
      manualFirstRound: [
        for (var i = 0; i < t.manualFirstRound.length; i++)
          if (i != index) t.manualFirstRound[i],
      ],
    ));
  }

  /// Locks the field and generates the first Swiss round.
  Future<void> startTournament() async {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.registering) return;
    final active = t.players.where((p) => !p.dropped).toList();
    if (active.length < 2) return;

    final rounds = t.config.swissRounds <= 0
        ? t.config.copyWith(swissRounds: recommendedSwissRounds(active.length))
        : t.config;

    final firstRound = SwissPairing.pairNextRound(
      players: t.players,
      previousRounds: const [],
      fixedMatches: t.manualFirstRound,
    );
    await _commit(t.copyWith(
      config: rounds,
      status: TournamentStatus.swiss,
      swissRounds: [Round(number: 1, matches: firstRound)],
      manualFirstRound: const [],
    ));
  }

  // --- Playing -------------------------------------------------------------

  /// The round currently being played (last Swiss or last top-cut round).
  Round? get activeRound {
    final t = _tournament;
    if (t == null) return null;
    if (t.status == TournamentStatus.swiss && t.swissRounds.isNotEmpty) {
      return t.swissRounds.last;
    }
    if (t.status == TournamentStatus.topCut && t.topCutRounds.isNotEmpty) {
      return t.topCutRounds.last;
    }
    return null;
  }

  /// Reports a result for [matchIndex] within the active round.
  Future<void> reportResult(int matchIndex, MatchResult result) async {
    final t = _tournament;
    if (t == null) return;

    if (t.status == TournamentStatus.swiss) {
      await _commit(t.copyWith(
        swissRounds: _withReportedMatch(t.swissRounds, matchIndex, result),
      ));
    } else if (t.status == TournamentStatus.topCut) {
      await _commit(t.copyWith(
        topCutRounds: _withReportedMatch(t.topCutRounds, matchIndex, result),
      ));
    }
  }

  List<Round> _withReportedMatch(List<Round> rounds, int matchIndex, MatchResult result) {
    if (rounds.isEmpty) return rounds;
    final last = rounds.last;
    final updated = Round(
      number: last.number,
      matches: [
        for (var i = 0; i < last.matches.length; i++)
          if (i == matchIndex) last.matches[i].withResult(result) else last.matches[i],
      ],
    );
    return [...rounds.sublist(0, rounds.length - 1), updated];
  }

  /// Drops a player from future pairings (keeps their history).
  Future<void> dropPlayer(String playerId) async {
    final t = _tournament;
    if (t == null) return;
    await _commit(t.copyWith(
      players: [
        for (final p in t.players)
          if (p.id == playerId) p.copyWith(dropped: true) else p,
      ],
    ));
  }

  /// Standings computed live from the Swiss history.
  List<Standing> standings() {
    final t = _tournament;
    if (t == null) return const [];
    return StandingsCalculator.compute(t.players, t.swissRounds);
  }

  bool get canAdvance {
    final round = activeRound;
    return round != null && round.isComplete;
  }

  /// Advances to the next Swiss round, into the top cut, or to finished.
  Future<void> advance() async {
    final t = _tournament;
    if (t == null || !canAdvance) return;

    if (t.status == TournamentStatus.swiss) {
      if (t.swissRounds.length < t.config.swissRounds) {
        final next = SwissPairing.pairNextRound(
          players: t.players,
          previousRounds: t.swissRounds,
        );
        await _commit(t.copyWith(
          swissRounds: [
            ...t.swissRounds,
            Round(number: t.swissRounds.length + 1, matches: next),
          ],
        ));
      } else {
        await _startTopCutOrFinish(t);
      }
    } else if (t.status == TournamentStatus.topCut) {
      final last = t.topCutRounds.last;
      if (last.matches.length <= 1) {
        await _commit(t.copyWith(status: TournamentStatus.finished));
      } else {
        await _commit(t.copyWith(
          topCutRounds: [...t.topCutRounds, TopCut.nextRound(last)],
        ));
      }
    }
  }

  /// Whether the tournament can step back to the previous round/phase.
  bool get canGoBack {
    final t = _tournament;
    return t != null && t.status != TournamentStatus.registering;
  }

  /// Reverts the tournament to the previous step, discarding the current
  /// round's pairings/results. Walks back through phases:
  /// finished → top cut/Swiss, top cut → earlier top-cut round or Swiss,
  /// Swiss → earlier Swiss round or back to registration.
  Future<void> goToPreviousStep() async {
    final t = _tournament;
    if (t == null) return;
    switch (t.status) {
      case TournamentStatus.registering:
        return;
      case TournamentStatus.swiss:
        if (t.swissRounds.length > 1) {
          await _commit(t.copyWith(
            swissRounds: t.swissRounds.sublist(0, t.swissRounds.length - 1),
          ));
        } else {
          await _commit(t.copyWith(
            status: TournamentStatus.registering,
            swissRounds: const [],
          ));
        }
      case TournamentStatus.topCut:
        if (t.topCutRounds.length > 1) {
          await _commit(t.copyWith(
            topCutRounds: t.topCutRounds.sublist(0, t.topCutRounds.length - 1),
          ));
        } else {
          await _commit(t.copyWith(
            status: TournamentStatus.swiss,
            topCutRounds: const [],
          ));
        }
      case TournamentStatus.finished:
        // Re-open the last played phase so results can be corrected.
        await _commit(t.copyWith(
          status: t.topCutRounds.isEmpty
              ? TournamentStatus.swiss
              : TournamentStatus.topCut,
        ));
    }
  }

  Future<void> _startTopCutOrFinish(Tournament t) async {
    final size = t.config.topCutSize;
    final eligible = StandingsCalculator.compute(t.players, t.swissRounds)
        .where((s) => !s.player.dropped)
        .toList();
    if (size <= 0 || eligible.length < size) {
      await _commit(t.copyWith(status: TournamentStatus.finished));
      return;
    }
    await _commit(t.copyWith(
      status: TournamentStatus.topCut,
      topCutRounds: [TopCut.seed(eligible, size)],
    ));
  }

  /// The champion's id once the tournament is finished via a top cut.
  String? get championId {
    final t = _tournament;
    if (t == null || t.status != TournamentStatus.finished) return null;
    if (t.topCutRounds.isEmpty) return null;
    return TopCut.championOf(t.topCutRounds.last);
  }
}
