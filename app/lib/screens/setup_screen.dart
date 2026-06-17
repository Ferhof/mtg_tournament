import 'package:flutter/material.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

import '../state/tournament_controller.dart';

/// Registration screen: name the tournament, manage players and settings,
/// then start. Shown while [TournamentStatus.registering].
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.controller});

  final TournamentController controller;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _playerCtrl = TextEditingController();
  late final _nameCtrl =
      TextEditingController(text: widget.controller.tournament?.config.name ?? '');

  TournamentController get c => widget.controller;

  @override
  void dispose() {
    _playerCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureTournament() async {
    if (c.tournament == null) {
      await c.createTournament('Tournament');
    }
  }

  Future<void> _addPlayer() async {
    final name = _playerCtrl.text.trim();
    if (name.isEmpty) return;
    await _ensureTournament();
    await c.addPlayer(name);
    _playerCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final t = c.tournament;
        final players = t?.players ?? const [];
        final activeCount = players.where((p) => !p.dropped).length;

        return Scaffold(
          appBar: AppBar(title: const Text('New tournament')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tournament name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) async {
                  await _ensureTournament();
                  await c.updateConfig(name: v);
                },
              ),
              const SizedBox(height: 24),
              Text('Players ($activeCount)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _playerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Add player',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addPlayer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _addPlayer, child: const Text('Add')),
                ],
              ),
              const SizedBox(height: 8),
              for (final p in players)
                ListTile(
                  dense: true,
                  title: Text(p.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => c.removePlayer(p.id),
                  ),
                ),
              const Divider(height: 32),
              _SettingsSection(controller: c, playerCount: activeCount),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: activeCount >= 2 ? c.startTournament : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(activeCount >= 2
                    ? 'Start tournament'
                    : 'Add at least 2 players'),
              ),
              if (t != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: c.reset,
                  child: const Text('Clear everything'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.controller, required this.playerCount});

  final TournamentController controller;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    final config = controller.tournament?.config;
    final recommended = recommendedSwissRounds(playerCount);
    final swissRounds =
        (config == null || config.swissRounds <= 0) ? recommended : config.swissRounds;
    final bestOf = config?.bestOf ?? 3;
    final topCut = config?.topCutSize ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _Stepper(
          label: 'Swiss rounds (recommended $recommended)',
          value: swissRounds,
          min: 1,
          max: 12,
          onChanged: (v) async {
            if (controller.tournament == null) {
              await controller.createTournament('Tournament');
            }
            await controller.updateConfig(swissRounds: v);
          },
        ),
        _Stepper(
          label: 'Best of',
          value: bestOf,
          min: 1,
          max: 7,
          step: 2,
          onChanged: (v) async {
            if (controller.tournament == null) {
              await controller.createTournament('Tournament');
            }
            await controller.updateConfig(bestOf: v);
          },
        ),
        const SizedBox(height: 8),
        const Text('Top cut'),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('None')),
            ButtonSegment(value: 4, label: Text('Top 4')),
            ButtonSegment(value: 8, label: Text('Top 8')),
          ],
          selected: {topCut},
          onSelectionChanged: (s) async {
            if (controller.tournament == null) {
              await controller.createTournament('Tournament');
            }
            await controller.updateConfig(topCutSize: s.first);
          },
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
          ),
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}
