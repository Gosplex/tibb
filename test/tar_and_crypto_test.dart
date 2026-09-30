import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tibb/features/export_import/crypto_box.dart';
import 'package:tibb/features/export_import/tar.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('tibb-test'));
  tearDown(() async => dir.delete(recursive: true));

  test('tar round-trips bytes and files', () async {
    final payload = File('${dir.path}/blob.bin')
      ..writeAsBytesSync(List<int>.generate(70000, (i) => i % 251));
    final tar = File('${dir.path}/a.tar');
    final w = TarWriter(tar.openWrite());
    await w.addBytes('manifest.json', '{"a":1}'.codeUnits);
    await w.addFile('blobs/abc.bin', payload);
    await w.close();

    final seen = <String, int>{};
    await readTar(tar, (entry, data) async {
      final bytes = await data.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      seen[entry.name] = bytes.length;
    });
    expect(seen, {'manifest.json': 7, 'blobs/abc.bin': 70000});
  });

  test('encryption round-trips and rejects a wrong password', () async {
    final rnd = Random(1);
    final input = File('${dir.path}/plain')
      ..writeAsBytesSync(List<int>.generate(300000, (_) => rnd.nextInt(256)));
    final enc = File('${dir.path}/enc');
    final out = File('${dir.path}/out');
    // Small KDF params keep the test fast; production uses the defaults.
    await encryptFile(input, enc, 'correct horse', params: const KdfParams(memoryKiB: 64, iterations: 1), chunkSize: 65536);
    expect(await isEncryptedArchive(enc), isTrue);
    await decryptFile(enc, out, 'correct horse');
    expect(out.readAsBytesSync(), input.readAsBytesSync());
    await expectLater(decryptFile(enc, File('${dir.path}/bad'), 'wrong'), throwsA(isA<WrongPasswordException>()));
  });

  test('truncated ciphertext is detected', () async {
    final input = File('${dir.path}/plain')..writeAsBytesSync(List<int>.filled(200000, 7));
    final enc = File('${dir.path}/enc');
    await encryptFile(input, enc, 'pw', params: const KdfParams(memoryKiB: 64, iterations: 1), chunkSize: 65536);
    final bytes = enc.readAsBytesSync();
    // Drop the last chunk entirely: the new final chunk wasn't flagged "last".
    final cut = File('${dir.path}/cut')..writeAsBytesSync(bytes.sublist(0, 36 + (12 + 4 + 65536 + 16) * 3));
    await expectLater(decryptFile(cut, File('${dir.path}/o'), 'pw'), throwsA(isA<CorruptArchiveException>()));
  });
}
