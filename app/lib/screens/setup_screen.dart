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

  Future<void> _addPlayer([String? name]) async {
    final value = (name ?? _playerCtrl.text).trim();
    if (value.isEmpty) return;
    await _ensureTournament();
    await c.addPlayer(value);
    _playerCtrl.clear();
  }

  /// Roster names not already present in the current tournament.
  List<String> _availableRosterNames(List<Player> players) {
    final present = players.map((p) => p.name.toLowerCase()).toSet();
    return c.rosterNames
        .where((n) => !present.contains(n.toLowerCase()))
        .toList();
  }

  Future<void> _manageRoster() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ManageRosterDialog(controller: c),
    );
  }

  Future<void> _addPairingDialog() async {
    final pool = c.unpairedPlayers;
    if (pool.length < 2) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _PairingDialog(controller: c, pool: pool),
    );
  }

  Future<void> _addByeDialog() async {
    final pool = c.unpairedPlayers;
    if (pool.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _ByeDialog(controller: c, pool: pool),
    );
  }

  String _playerName(String id) =>
      c.tournament?.playerById(id)?.name ?? '???';

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
                  FilledButton(
                      onPressed: () => _addPlayer(), child: const Text('Add')),
                ],
              ),
              if (_availableRosterNames(players).isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('From roster',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    TextButton.icon(
                      onPressed: _manageRoster,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final name in _availableRosterNames(players))
                      ActionChip(
                        label: Text(name),
                        avatar: const Icon(Icons.add, size: 18),
                        onPressed: () => _addPlayer(name),
                      ),
                  ],
                ),
              ] else if (c.rosterNames.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _manageRoster,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Manage roster'),
                  ),
                ),
              ],
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
              if (players.length >= 2) ...[
                const Divider(height: 32),
                _FirstRoundSection(
                  controller: c,
                  playerName: _playerName,
                  onAddPairing: _addPairingDialog,
                  onAddBye: _addByeDialog,
                ),
              ],
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

/// Optional manual pairings/byes for the first round. Anyone left unpaired is
/// paired automatically when the tournament starts.
class _FirstRoundSection extends StatelessWidget {
  const _FirstRoundSection({
    required this.controller,
    required this.playerName,
    required this.onAddPairing,
    required this.onAddBye,
  });

  final TournamentController controller;
  final String Function(String id) playerName;
  final VoidCallback onAddPairing;
  final VoidCallback onAddBye;

  @override
  Widget build(BuildContext context) {
    final manual = controller.tournament?.manualFirstRound ?? const [];
    final unpaired = controller.unpairedPlayers;
    final canAddBye = controller.canAddManualBye;
    final activeCount =
        controller.tournament?.players.where((p) => !p.dropped).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('First-round pairings (optional)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Остальные игроки спарятся автоматически.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < manual.length; i++)
          ListTile(
            dense: true,
            leading: Icon(manual[i].isBye
                ? Icons.airline_seat_individual_suite_outlined
                : Icons.sports_kabaddi_outlined),
            title: Text(manual[i].isBye
                ? 'Bye: ${playerName(manual[i].player1Id)}'
                : '${playerName(manual[i].player1Id)} '
                    'vs ${playerName(manual[i].player2Id!)}'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => controller.removeManualMatch(i),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: unpaired.length >= 2 ? onAddPairing : null,
              icon: const Icon(Icons.add),
              label: const Text('Add pairing'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: canAddBye ? onAddBye : null,
              icon: const Icon(Icons.add),
              label: const Text('Add bye'),
            ),
          ],
        ),
        if (!canAddBye && activeCount.isEven)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Бай можно выдать только при нечётном числе игроков.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
      ],
    );
  }
}

/// Dialog to view, rename and delete roster entries.
class _ManageRosterDialog extends StatelessWidget {
  const _ManageRosterDialog({required this.controller});

  final TournamentController controller;

  Future<void> _rename(BuildContext context, String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename player'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await controller.renameInRoster(oldName, newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Roster'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final names = controller.rosterNames;
            if (names.isEmpty) {
              return const Text('Roster is empty.');
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final name in names)
                  ListTile(
                    dense: true,
                    title: Text(name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(context, name),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => controller.removeFromRoster(name),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Dialog to manually pair two of the unpaired players.
class _PairingDialog extends StatefulWidget {
  const _PairingDialog({required this.controller, required this.pool});

  final TournamentController controller;
  final List<Player> pool;

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  String? _first;
  String? _second;

  @override
  Widget build(BuildContext context) {
    final canSave = _first != null && _second != null && _first != _second;
    return AlertDialog(
      title: const Text('Add pairing'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _first,
            decoration: const InputDecoration(labelText: 'Player 1'),
            items: [
              for (final p in widget.pool)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _first = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _second,
            decoration: const InputDecoration(labelText: 'Player 2'),
            items: [
              for (final p in widget.pool)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _second = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave
              ? () {
                  widget.controller.addManualPairing(_first!, _second!);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Dialog to grant a manual first-round bye to one of the unpaired players.
class _ByeDialog extends StatefulWidget {
  const _ByeDialog({required this.controller, required this.pool});

  final TournamentController controller;
  final List<Player> pool;

  @override
  State<_ByeDialog> createState() => _ByeDialogState();
}

class _ByeDialogState extends State<_ByeDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add bye'),
      content: DropdownButtonFormField<String>(
        initialValue: _selected,
        decoration: const InputDecoration(labelText: 'Player'),
        items: [
          for (final p in widget.pool)
            DropdownMenuItem(value: p.id, child: Text(p.name)),
        ],
        onChanged: (v) => setState(() => _selected = v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected != null
              ? () {
                  widget.controller.addManualBye(_selected!);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Add'),
        ),
      ],
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
