// LockService — session state for locked boxes (brief §7.4).
// Unlocks last until the app goes to the background or 60 s of inactivity in a
// locked box; then everything re-locks. The Bridge can see locked boxes only
// when the owner explicitly shares them for that session (with biometrics).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

enum UnlockResult { success, failed, unavailable }

class LockService extends ChangeNotifier with WidgetsBindingObserver {
  LockService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final LocalAuthentication _auth = LocalAuthentication();
  final Set<String> _unlocked = {};
  Timer? _idle;

  bool shareLockedWithBridge = false;

  Set<String> get unlockedBoxIds => Set.unmodifiable(_unlocked);
  bool isUnlocked(String boxId) => _unlocked.contains(boxId);

  /// True when the device has any lock (biometric or passcode) that can gate content.
  Future<bool> canLock() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<UnlockResult> authenticate(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockResult.unavailable;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Passcode fallback is allowed (design §9.12): never lock people out of their own box.
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      return ok ? UnlockResult.success : UnlockResult.failed;
    } on PlatformException catch (e) {
      debugPrint('Tibb: auth error ${e.code}');
      return e.code == 'NotAvailable' || e.code == 'PasscodeNotSet'
          ? UnlockResult.unavailable
          : UnlockResult.failed;
    }
  }

  Future<UnlockResult> unlock(String boxId, String boxName) async {
    final r = await authenticate('Open $boxName');
    if (r == UnlockResult.success) {
      _unlocked.add(boxId);
      touch();
      notifyListeners();
    }
    return r;
  }

  /// Resets the 60 s idle timer while the user is active in an unlocked box.
  void touch() {
    _idle?.cancel();
    if (_unlocked.isEmpty) return;
    _idle = Timer(const Duration(seconds: 60), lockAll);
  }

  void lockAll() {
    _idle?.cancel();
    if (_unlocked.isEmpty && !shareLockedWithBridge) return;
    _unlocked.clear();
    shareLockedWithBridge = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` also fires for Face ID sheets and Control Center on iOS, so we
    // only re-lock on `paused` (actually backgrounded).
    if (state == AppLifecycleState.paused) lockAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle?.cancel();
    super.dispose();
  }
}
