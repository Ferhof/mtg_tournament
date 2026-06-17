import 'package:flutter/material.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

import '../state/tournament_controller.dart';
import 'result_dialog.dart';

/// Single-elimination bracket screen. Also shows the champion banner once the
/// tournament is finished.
class TopCutScreen extends StatelessWidget {
  const TopCutScreen({super.key, required this.controller});

  final TournamentController controller;

  String _roundLabel(int matchCount) => switch (matchCount) {
        1 => 'Final',
        2 => 'Semifinals',
        4 => 'Quarterfinals',
        _ => 'Round',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = controller.tournament!;
        final finished = t.status == TournamentStatus.finished;
        final championId = controller.championId;

        return Scaffold(
          appBar: AppBar(title: Text('${t.config.name} — Top cut')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (finished && championId != null)
                _ChampionBanner(name: t.playerById(championId)?.name ?? championId),
              for (final round in t.topCutRounds) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _roundLabel(round.matches.length),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (var i = 0; i < round.matches.length; i++)
                  _BracketMatch(
                    controller: controller,
                    round: round,
                    matchIndex: i,
                    // Only the latest round is editable.
                    editable: !finished && round == t.topCutRounds.last,
                  ),
              ],
              const SizedBox(height: 24),
              if (finished)
                FilledButton.icon(
                  onPressed: controller.reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New tournament'),
                ),
            ],
          ),
          floatingActionButton: (!finished && controller.canAdvance)
              ? FloatingActionButton.extended(
                  onPressed: () => controller.advance(),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(t.topCutRounds.last.matches.length <= 1
                      ? 'Finish'
                      : 'Next round'),
                )
              : null,
        );
      },
    );
  }
}

class _BracketMatch extends StatelessWidget {
  const _BracketMatch({
    required this.controller,
    required this.round,
    required this.matchIndex,
    required this.editable,
  });

  final TournamentController controller;
  final Round round;
  final int matchIndex;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final t = controller.tournament!;
    final m = round.matches[matchIndex];
    final p1 = t.playerById(m.player1Id)?.name ?? m.player1Id;
    final p2 = t.playerById(m.player2Id!)?.name ?? m.player2Id!;
    final r = m.result;

    String? winner;
    if (r != null) winner = r.player1Won ? p1 : p2;

    return Card(
      child: ListTile(
        title: Text('$p1  vs  $p2'),
        subtitle: Text(r == null ? 'Not reported' : 'Result: $r  •  Winner: $winner'),
        trailing: editable ? const Icon(Icons.edit_outlined) : null,
        onTap: editable
            ? () async {
                final result = await showResultDialog(
                  context,
                  player1Name: p1,
                  player2Name: p2,
                  bestOf: t.config.bestOf,
                  allowDraw: false,
                  initial: r,
                );
                if (result != null) {
                  await controller.reportResult(matchIndex, result);
                }
              }
            : null,
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.emoji_events, size: 48),
            const SizedBox(height: 8),
            Text('Champion', style: Theme.of(context).textTheme.titleSmall),
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
