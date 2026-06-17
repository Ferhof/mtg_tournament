import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

import 'package:mtg_tournament_app/data/player_roster_repository.dart';
import 'package:mtg_tournament_app/data/tournament_repository.dart';
import 'package:mtg_tournament_app/main.dart';
import 'package:mtg_tournament_app/state/tournament_controller.dart';

/// In-memory repository so widget tests don't touch the filesystem.
class _FakeRepo implements TournamentRepository {
  Tournament? _saved;

  @override
  Future<Tournament?> load() async => _saved;

  @override
  Future<void> save(Tournament tournament) async => _saved = tournament;

  @override
  Future<void> clear() async => _saved = null;
}

/// In-memory roster repository for tests.
class _FakeRosterRepo implements PlayerRosterRepository {
  List<String> _names = const [];

  @override
  Future<List<String>> load() async => _names;

  @override
  Future<void> save(List<String> names) async => _names = names;
}

void main() {
  testWidgets('starts on the setup screen with no saved tournament',
      (tester) async {
    final controller =
        TournamentController(_FakeRepo(), _FakeRosterRepo());
    await controller.init();

    await tester.pumpWidget(MtgTournamentApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('New tournament'), findsOneWidget);
    expect(find.text('Add at least 2 players'), findsOneWidget);
  });

  testWidgets('adding two players enables starting the tournament',
      (tester) async {
    final controller =
        TournamentController(_FakeRepo(), _FakeRosterRepo());
    await controller.init();
    await controller.createTournament('Test Cup');
    await controller.addPlayer('Alice');
    await controller.addPlayer('Bob');

    await tester.pumpWidget(MtgTournamentApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // The start button lives at the bottom of a scrollable list.
    await tester.scrollUntilVisible(find.text('Start tournament'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Start tournament'), findsOneWidget);
  });
}
