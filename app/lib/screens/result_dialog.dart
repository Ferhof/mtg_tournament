import 'package:flutter/material.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

/// Shows a dialog to enter (or edit) a [MatchResult] for a match.
///
/// [allowDraw] is false for single-elimination matches, which must have a
/// winner. Returns the chosen result, or `null` if cancelled.
Future<MatchResult?> showResultDialog(
  BuildContext context, {
  required String player1Name,
  required String player2Name,
  required int bestOf,
  bool allowDraw = true,
  MatchResult? initial,
}) {
  return showDialog<MatchResult>(
    context: context,
    builder: (context) => _ResultDialog(
      player1Name: player1Name,
      player2Name: player2Name,
      bestOf: bestOf,
      allowDraw: allowDraw,
      initial: initial,
    ),
  );
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({
    required this.player1Name,
    required this.player2Name,
    required this.bestOf,
    required this.allowDraw,
    this.initial,
  });

  final String player1Name;
  final String player2Name;
  final int bestOf;
  final bool allowDraw;
  final MatchResult? initial;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  late int p1 = widget.initial?.player1GameWins ?? 0;
  late int p2 = widget.initial?.player2GameWins ?? 0;
  late int draws = widget.initial?.gameDraws ?? 0;

  int get _maxGames => widget.bestOf;

  bool get _valid {
    if (p1 == p2 && !widget.allowDraw) return false;
    return p1 + p2 + draws > 0;
  }

  @override
  Widget build(BuildContext context) {
    final winTarget = (widget.bestOf ~/ 2) + 1;
    return AlertDialog(
      title: const Text('Match result'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.bestOf > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _quick('$winTarget-0', winTarget, 0),
                    if (winTarget > 1) _quick('$winTarget-${winTarget - 1}', winTarget, winTarget - 1),
                    if (winTarget > 1) _quick('${winTarget - 1}-$winTarget', winTarget - 1, winTarget),
                    _quick('0-$winTarget', 0, winTarget),
                  ],
                ),
              ),
            _GameRow(
              name: widget.player1Name,
              value: p1,
              max: _maxGames,
              onChanged: (v) => setState(() => p1 = v),
            ),
            _GameRow(
              name: widget.player2Name,
              value: p2,
              max: _maxGames,
              onChanged: (v) => setState(() => p2 = v),
            ),
            if (widget.allowDraw)
              _GameRow(
                name: 'Draws',
                value: draws,
                max: _maxGames,
                onChanged: (v) => setState(() => draws = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                    context,
                    MatchResult(
                      player1GameWins: p1,
                      player2GameWins: p2,
                      gameDraws: draws,
                    ),
                  )
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _quick(String label, int a, int b) => ActionChip(
        label: Text(label),
        onPressed: () => setState(() {
          p1 = a;
          p2 = b;
          draws = 0;
        }),
      );
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.name,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String name;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
