import 'package:flutter/material.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

import 'data/tournament_repository.dart';
import 'screens/setup_screen.dart';
import 'screens/swiss_screen.dart';
import 'screens/top_cut_screen.dart';
import 'state/tournament_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = TournamentController(TournamentRepository());
  controller.init();
  runApp(MtgTournamentApp(controller: controller));
}

class MtgTournamentApp extends StatelessWidget {
  const MtgTournamentApp({super.key, required this.controller});

  final TournamentController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTG Tournament',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6A4FB6),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6A4FB6),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final t = controller.tournament;
          if (t == null || t.status == TournamentStatus.registering) {
            return SetupScreen(controller: controller);
          }
          switch (t.status) {
            case TournamentStatus.swiss:
              return SwissScreen(controller: controller);
            case TournamentStatus.topCut:
            case TournamentStatus.finished:
              return TopCutScreen(controller: controller);
            case TournamentStatus.registering:
              return SetupScreen(controller: controller);
          }
        },
      ),
    );
  }
}
