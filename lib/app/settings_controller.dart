import 'package:flutter/material.dart';

import '../core/repository/library_repository.dart';

/// Appearance and small preferences, persisted in the meta table.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repo) {
    _themeMode = switch (_repo.getMeta('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _hideCounts = _repo.flag('hide_counts');
  }

  final LibraryRepository _repo;
  late ThemeMode _themeMode;
  late bool _hideCounts;

  ThemeMode get themeMode => _themeMode;
  bool get hideUnreviewedCounts => _hideCounts;

  set themeMode(ThemeMode m) {
    _themeMode = m;
    _repo.setMeta('theme_mode', m.name);
    notifyListeners();
  }

  set hideUnreviewedCounts(bool v) {
    _hideCounts = v;
    _repo.setMeta('hide_counts', v ? '1' : '0');
    notifyListeners();
  }
}
