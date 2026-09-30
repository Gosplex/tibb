import 'dart:math';

final Random _secure = Random.secure();

/// Random UUID v4. Used for entity and device IDs — never tied to identity.
String newId() {
  final b = List<int>.generate(16, (_) => _secure.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Cryptographically random hex token (Bridge session tokens).
String randomHex(int bytes) => List<int>.generate(bytes, (_) => _secure.nextInt(256))
    .map((x) => x.toRadixString(16).padLeft(2, '0'))
    .join();

/// Random numeric code of [digits] length (Bridge pairing code).
String randomDigits(int digits) => List<int>.generate(digits, (_) => _secure.nextInt(10)).join();
