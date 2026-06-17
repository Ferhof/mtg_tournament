import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

import 'package:mtg_tournament_app/data/player_roster_repository.dart';
import 'package:mtg_tournament_app/data/tournament_repository.dart';
import 'package:mtg_tournament_app/state/tournament_controller.dart';

class _FakeRepo implements TournamentRepository {
  Tournament? _saved;
  @override
  Future<Tournament?> load() async => _saved;
  @override
  Future<void> save(Tournament tournament) async => _saved = tournament;
  @override
  Future<void> clear() async => _saved = null;
}

class _FakeRosterRepo implements PlayerRosterRepository {
  List<String> _names = const [];
  @override
  Future<List<String>> load() async => _names;
  @override
  Future<void> save(List<String> names) async => _names = names;
}

TournamentController _newController() =>
    TournamentController(_FakeRepo(), _FakeRosterRepo());

Future<TournamentController> _withPlayers(int count) async {
  final c = _newController();
  await c.init();
  await c.createTournament('T');
  for (var i = 0; i < count; i++) {
    await c.addPlayer('P$i');
  }
  return c;
}

void main() {
  group('Manual bye guard', () {
    test('forbidden when the field is even', () async {
      final c = await _withPlayers(4);
      expect(c.canAddManualBye, isFalse);
      await c.addManualBye(c.tournament!.players.first.id);
      expect(c.tournament!.manualFirstRound, isEmpty);
    });

    test('allowed once when the field is odd', () async {
      final c = await _withPlayers(5);
      expect(c.canAddManualBye, isTrue);
      await c.addManualBye(c.tournament!.players.first.id);
      expect(c.tournament!.manualFirstRound.where((m) => m.isBye).length, 1);
      // No second bye allowed.
      expect(c.canAddManualBye, isFalse);
      await c.addManualBye(c.tournament!.players[1].id);
      expect(c.tournament!.manualFirstRound.where((m) => m.isBye).length, 1);
    });
  });

  group('Roster auto-accumulation', () {
    test('adding a player records the name in the roster', () async {
      final c = await _withPlayers(2);
      expect(c.rosterNames, containsAll(['P0', 'P1']));
    });
  });

  group('Step back', () {
    test('walks from finished Swiss back to registration', () async {
      final c = await _withPlayers(2);
      await c.startTournament();
      expect(c.tournament!.status, TournamentStatus.swiss);
      expect(c.tournament!.swissRounds.length, 1);

      // Back from the first Swiss round returns to registration.
      await c.goToPreviousStep();
      expect(c.tournament!.status, TournamentStatus.registering);
      expect(c.tournament!.swissRounds, isEmpty);
      expect(c.canGoBack, isFalse);
    });
  });
}
