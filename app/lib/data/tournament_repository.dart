import 'dart:convert';
import 'dart:io';

import 'package:mtg_tournament_engine/tournament_engine.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the current [Tournament] to a single JSON file in the app's
/// documents directory. Offline, single-device — no database needed.
class TournamentRepository {
  static const _fileName = 'tournament.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Loads the saved tournament, or `null` if nothing has been saved yet.
  Future<Tournament?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return Tournament.fromJson(json);
    } catch (_) {
      // Corrupt or unreadable save — treat as no tournament rather than crash.
      return null;
    }
  }

  /// Writes [tournament] to disk, overwriting any previous save.
  Future<void> save(Tournament tournament) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(tournament.toJson()));
  }

  /// Removes the saved tournament (used when starting over).
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
