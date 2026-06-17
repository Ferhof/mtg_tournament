import 'package:flutter/material.dart';

import '../state/tournament_controller.dart';
import 'confirm_dialog.dart';

/// AppBar overflow menu shared by the in-progress and finished screens:
/// step back to the previous round/phase, or reset the whole tournament.
/// Both actions are destructive and ask for confirmation first.
class TournamentMenu extends StatelessWidget {
  const TournamentMenu({super.key, required this.controller});

  final TournamentController controller;

  Future<void> _back(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Step back',
      message: 'Вернуться на прошлый шаг? Текущий раунд и его результаты '
          'будут удалены.',
      confirmLabel: 'Step back',
      destructive: true,
    );
    if (ok) await controller.goToPreviousStep();
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Reset tournament',
      message: 'Вы уверены, что хотите сбросить турнир? Все раунды, '
          'результаты и состав будут безвозвратно удалены.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (ok) await controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'back':
            _back(context);
          case 'reset':
            _reset(context);
        }
      },
      itemBuilder: (context) => [
        if (controller.canGoBack)
          const PopupMenuItem(
            value: 'back',
            child: ListTile(
              leading: Icon(Icons.undo),
              title: Text('Step back'),
            ),
          ),
        const PopupMenuItem(
          value: 'reset',
          child: ListTile(
            leading: Icon(Icons.refresh),
            title: Text('Reset tournament'),
          ),
        ),
      ],
    );
  }
}
