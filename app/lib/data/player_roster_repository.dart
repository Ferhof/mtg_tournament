import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists the roster of known player names — everyone who has ever been added
/// to a tournament — so they can be quickly re-added later. Stored as a single
/// JSON list in the app's documents directory, independent of any tournament.
class PlayerRosterRepository {
  static const _fileName = 'roster.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Loads the saved roster, or an empty list if nothing has been saved yet.
  Future<List<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = (jsonDecode(raw) as List).cast<String>();
      return _normalize(list);
    } catch (_) {
      // Corrupt or unreadable save — treat as an empty roster rather than crash.
      return [];
    }
  }

  /// Writes [names] to disk (deduplicated case-insensitively, sorted).
  Future<void> save(List<String> names) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(_normalize(names)));
  }

  /// Deduplicates names case-insensitively (first spelling wins) and sorts them.
  static List<String> _normalize(List<String> names) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) out.add(name);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }
}
