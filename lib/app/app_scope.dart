import 'package:flutter/widgets.dart';

import '../core/repository/library_repository.dart';
import '../features/bridge/bridge_server.dart';
import '../features/locked/lock_service.dart';
import '../features/paywall/pro_service.dart';
import 'settings_controller.dart';

/// Holds the app's long-lived services. Created once in main(); screens read
/// them with `AppScope.of(context)` and listen with ListenableBuilder.
class AppServices {
  AppServices({
    required this.repo,
    required this.pro,
    required this.locks,
    required this.bridge,
    required this.settings,
  });

  final LibraryRepository repo;
  final ProService pro;
  final LockService locks;
  final BridgeServer bridge;
  final SettingsController settings;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
