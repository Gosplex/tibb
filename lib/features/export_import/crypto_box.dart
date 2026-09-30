// Password-protected export (brief §7.13): Argon2id key derivation + AES-256-GCM
// in 1 MiB chunks, so any size archive encrypts in constant memory.
//
// File layout (all integers big-endian):
//   magic "TIBBENC1" (8) | salt (16) | memoryKiB u32 | iterations u32 | chunkSize u32
//   then per chunk: nonce (12) | cipherLength u32 | ciphertext | mac (16)
// Each chunk's AAD = header bytes + chunk index (u64) + last flag (u8), which
// makes reordering, dropping or truncating chunks detectable.
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const _magic = [0x54, 0x49, 0x42, 0x42, 0x45, 0x4E, 0x43, 0x31]; // TIBBENC1
const _headerLength = 8 + 16 + 4 + 4 + 4;
const _defaultChunk = 1024 * 1024;

class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

class CorruptArchiveException implements Exception {
  const CorruptArchiveException(this.reason);
  final String reason;
  @override
  String toString() => 'CorruptArchiveException: $reason';
}

/// KDF parameters. Defaults follow OWASP's Argon2id minimum (19 MiB, t=2, p=1).
class KdfParams {
  const KdfParams({this.memoryKiB = 19456, this.iterations = 2});
  final int memoryKiB;
  final int iterations;
}

Future<bool> isEncryptedArchive(File f) async {
  final raf = await f.open();
  try {
    final head = await raf.read(8);
    if (head.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (head[i] != _magic[i]) return false;
    }
    return true;
  } finally {
    await raf.close();
  }
}

/// Argon2id runs in a background isolate so the UI keeps animating.
Future<SecretKey> _deriveKey(String password, List<int> salt, KdfParams params) async {
  final bytes = await Isolate.run(() async {
    final kdf = Argon2id(
      parallelism: 1,
      memory: params.memoryKiB,
      iterations: params.iterations,
      hashLength: 32,
    );
    final key = await kdf.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  });
  return SecretKey(bytes);
}

Future<void> encryptFile(File input, File output, String password,
    {KdfParams params = const KdfParams(), int chunkSize = _defaultChunk, void Function(double)? onProgress}) async {
  final rnd = Random.secure();
  final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
  final header = BytesBuilder()
    ..add(_magic)
    ..add(salt)
    ..add(_u32(params.memoryKiB))
    ..add(_u32(params.iterations))
    ..add(_u32(chunkSize));
  final headerBytes = header.toBytes();
  final key = await _deriveKey(password, salt, params);
  final aes = AesGcm.with256bits();

  final total = await input.length();
  final src = await input.open();
  final out = output.openWrite();
  try {
    out.add(headerBytes);
    var index = 0;
    var done = 0;
    // An empty input still gets one (empty, last) chunk so truncation is detectable.
    do {
      final chunk = await src.read(chunkSize);
      done += chunk.length;
      final last = done >= total;
      final nonce = aes.newNonce();
      final box = await aes.encrypt(chunk, secretKey: key, nonce: nonce, aad: _aad(headerBytes, index, last));
      out
        ..add(nonce)
        ..add(_u32(box.cipherText.length))
        ..add(box.cipherText)
        ..add(box.mac.bytes);
      index++;
      onProgress?.call(total == 0 ? 1 : done / total);
      if (last) break;
    } while (true);
    await out.flush();
  } finally {
    await out.close();
    await src.close();
  }
}

Future<void> decryptFile(File input, File output, String password, {void Function(double)? onProgress}) async {
  final src = await input.open();
  final out = output.openWrite();
  try {
    final total = await src.length();
    final headerBytes = await src.read(_headerLength);
    if (headerBytes.length < _headerLength) throw const CorruptArchiveException('short header');
    for (var i = 0; i < 8; i++) {
      if (headerBytes[i] != _magic[i]) throw const CorruptArchiveException('not a Tibb encrypted archive');
    }
    final salt = headerBytes.sublist(8, 24);
    final memory = _readU32(headerBytes, 24);
    final iterations = _readU32(headerBytes, 28);
    if (memory < 8 || memory > 1024 * 1024 || iterations < 1 || iterations > 64) {
      throw const CorruptArchiveException('bad KDF parameters');
    }
    final key = await _deriveKey(password, salt, KdfParams(memoryKiB: memory, iterations: iterations));
    final aes = AesGcm.with256bits();

    var index = 0;
    var sawLast = false;
    while (await src.position() < total) {
      final nonce = await src.read(12);
      final lenBytes = await src.read(4);
      if (nonce.length < 12 || lenBytes.length < 4) throw const CorruptArchiveException('truncated chunk header');
      final len = _readU32(lenBytes, 0);
      if (len > 64 * 1024 * 1024) throw const CorruptArchiveException('chunk too large');
      final cipher = await src.read(len);
      final mac = await src.read(16);
      if (cipher.length < len || mac.length < 16) throw const CorruptArchiveException('truncated chunk');
      final last = await src.position() >= total;
      final List<int> clear;
      try {
        clear = await aes.decrypt(
          SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
          secretKey: key,
          aad: _aad(headerBytes, index, last),
        );
      } on SecretBoxAuthenticationError {
        // The first chunk failing almost always means the password is wrong.
        if (index == 0) throw const WrongPasswordException();
        throw const CorruptArchiveException('chunk failed authentication');
      }
      out.add(clear);
      sawLast = last;
      index++;
      onProgress?.call(total == 0 ? 1 : (await src.position()) / total);
    }
    if (!sawLast) throw const CorruptArchiveException('missing final chunk');
    await out.flush();
  } finally {
    await out.close();
    await src.close();
  }
}

List<int> _aad(List<int> header, int index, bool last) {
  final b = BytesBuilder()..add(header);
  final idx = ByteData(8)..setUint64(0, index);
  b.add(idx.buffer.asUint8List());
  b.addByte(last ? 1 : 0);
  return b.toBytes();
}

List<int> _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();

int _readU32(List<int> b, int offset) =>
    ByteData.sublistView(Uint8List.fromList(b.sublist(offset, offset + 4))).getUint32(0);
