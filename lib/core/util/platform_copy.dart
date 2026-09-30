import 'dart:io';

/// Wording that differs between Android and iPhone, in one place, so no
/// screen says "Face ID" on a Pixel or "Google Play" on an iPhone.
abstract final class PlatformCopy {
  static bool get _ios => Platform.isIOS;

  /// "Face ID or your passcode" / "your fingerprint or screen lock"
  static String get unlockMethod => _ios ? 'Face ID or your passcode' : 'your fingerprint or screen lock';

  /// Short form for tight spaces: "Face ID" / "fingerprint".
  static String get biometricShort => _ios ? 'Face ID' : 'fingerprint';

  static String get store => _ios ? 'App Store' : 'Google Play';

  static String get storeCompany => _ios ? 'Apple' : 'Google Play';

  /// Why the computer can only see Tibb while it's open.
  static String get keepOpenReason => _ios
      ? 'iPhone pauses apps in the background, so your computer only sees Tibb while it is on screen.'
      : 'Some phones pause apps in the background to save battery, so keep Tibb on screen while you use your computer.';
}
