import 'package:flutter/material.dart';

import '../state/tournament_controller.dart';
import 'confirm_dialog.dart';
import 'standings_list.dart';
import 'tournament_menu.dart';

/// Final screen for a tournament that finished without a top cut: shows the
/// final standings and the winner, plus the back/reset menu.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.controller});

  final TournamentController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = controller.tournament!;
        final standings = controller.standings();
        final winner = standings.isNotEmpty ? standings.first.player.name : null;

        return Scaffold(
          appBar: AppBar(
            title: Text('${t.config.name} — Results'),
            actions: [TournamentMenu(controller: controller)],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (winner != null) _WinnerBanner(name: winner),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Final standings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StandingsList(
                standings: standings,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'New tournament',
                    message: 'Сбросить текущий турнир и начать новый?',
                    confirmLabel: 'New tournament',
                    destructive: true,
                  );
                  if (ok) await controller.reset();
                },
                icon: const Icon(Icons.add),
                label: const Text('New tournament'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.name});

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
            Text('Winner', style: Theme.of(context).textTheme.titleSmall),
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
