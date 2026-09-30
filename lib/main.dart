import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_scope.dart';
import 'app/settings_controller.dart';
import 'app/tibb_app.dart';
import 'core/platform/tibb_platform.dart';
import 'core/repository/library_repository.dart';
import 'features/bridge/arrival_notifier.dart';
import 'features/bridge/bridge_server.dart';
import 'features/locked/lock_service.dart';
import 'features/paywall/pro_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Native AES-GCM (CryptoKit on iOS) for encrypted export.
  FlutterCryptography.enable();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  TibbPlatform.instance.init();

  final repo = await LibraryRepository.open();
  final locks = LockService();
  final pro = ProService();
  final services = AppServices(
    repo: repo,
    pro: pro,
    locks: locks,
    bridge: BridgeServer(repo, locks),
    settings: SettingsController(repo),
  );

  // Event notifications ("Saved from Chrome on Windows") and the Stop button
  // on the Android Bridge notification.
  ArrivalNotifier(repo, services.bridge);
  TibbPlatform.instance.onBridgeStopRequested = () => services.bridge.stop();
  services.bridge.isPro = () => pro.isPro;

  runApp(AppScope(services: services, child: const TibbApp()));
  // Purchases never block first paint: the thread is usable immediately.
  await pro.init();
}
