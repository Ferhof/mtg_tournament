import 'package:flutter/material.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

import '../state/tournament_controller.dart';
import 'result_dialog.dart';
import 'standings_list.dart';
import 'tournament_menu.dart';

/// Main screen during the Swiss phase: tabs for the current round and the
/// live standings, plus an "advance" button.
class SwissScreen extends StatelessWidget {
  const SwissScreen({super.key, required this.controller});

  final TournamentController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = controller.tournament!;
        final round = controller.activeRound;
        final isLastSwiss = t.swissRounds.length >= t.config.swissRounds;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(t.config.name),
              actions: [TournamentMenu(controller: controller)],
              bottom: TabBar(
                tabs: [
                  Tab(text: 'Round ${round?.number ?? '-'} / ${t.config.swissRounds}'),
                  const Tab(text: 'Standings'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _RoundTab(controller: controller),
                _StandingsTab(controller: controller),
              ],
            ),
            floatingActionButton: controller.canAdvance
                ? FloatingActionButton.extended(
                    onPressed: () => controller.advance(),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(isLastSwiss
                        ? (t.config.topCutSize > 0 ? 'Start top cut' : 'Finish')
                        : 'Next round'),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _RoundTab extends StatelessWidget {
  const _RoundTab({required this.controller});

  final TournamentController controller;

  String _name(String id) =>
      controller.tournament?.playerById(id)?.name ?? id;

  @override
  Widget build(BuildContext context) {
    final round = controller.activeRound;
    if (round == null) return const SizedBox.shrink();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: round.matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = round.matches[i];
        return _MatchTile(
          controller: controller,
          matchIndex: i,
          match: m,
          name: _name,
          allowDraw: true,
        );
      },
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.controller,
    required this.matchIndex,
    required this.match,
    required this.name,
    required this.allowDraw,
  });

  final TournamentController controller;
  final int matchIndex;
  final Match match;
  final String Function(String id) name;
  final bool allowDraw;

  @override
  Widget build(BuildContext context) {
    final bestOf = controller.tournament!.config.bestOf;

    if (match.isBye) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.airline_seat_individual_suite),
          title: Text(name(match.player1Id)),
          subtitle: const Text('Bye — auto win'),
        ),
      );
    }

    final r = match.result;
    final p1 = name(match.player1Id);
    final p2 = name(match.player2Id!);

    return Card(
      child: ListTile(
        title: Text('$p1  vs  $p2'),
        subtitle: Text(r == null ? 'Not reported' : 'Result: $r'),
        trailing: r == null
            ? const Icon(Icons.edit_outlined)
            : Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
        onLongPress: () => _showDropMenu(context),
        onTap: () async {
          final result = await showResultDialog(
            context,
            player1Name: p1,
            player2Name: p2,
            bestOf: bestOf,
            allowDraw: allowDraw,
            initial: r,
          );
          if (result != null) {
            await controller.reportResult(matchIndex, result);
          }
        },
      ),
    );
  }

  void _showDropMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off),
              title: Text('Drop ${name(match.player1Id)}'),
              onTap: () {
                controller.dropPlayer(match.player1Id);
                Navigator.pop(context);
              },
            ),
            if (match.player2Id != null)
              ListTile(
                leading: const Icon(Icons.person_off),
                title: Text('Drop ${name(match.player2Id!)}'),
                onTap: () {
                  controller.dropPlayer(match.player2Id!);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StandingsTab extends StatelessWidget {
  const _StandingsTab({required this.controller});

  final TournamentController controller;

  @override
  Widget build(BuildContext context) {
    return StandingsList(standings: controller.standings());
  }
}
