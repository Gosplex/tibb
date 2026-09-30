// Export & import (brief §7.13). An archive is the whole change log plus every
// referenced blob, packed as a plain tar:
//
//   manifest.json      format, version, counts, exporting device
//   changes.jsonl      one ChangeEvent per line, oldest first
//   blobs/<hash><ext>  content-addressed media
//
// Import is all-or-nothing: every blob is hash-verified and every referenced
// blob must be present before a single event is applied, and the events are
// applied in one transaction. Re-importing the same archive adds nothing.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/blobs/blob_store.dart';
import '../../core/models.dart';
import '../../core/repository/library_repository.dart';
import 'crypto_box.dart';
import 'tar.dart';

const kArchiveFormat = 'tibb-archive';
const kArchiveVersion = 1;

class ImportResult {
  const ImportResult({required this.newEvents, required this.newItems, required this.blobs});
  final int newEvents;
  final int newItems;
  final int blobs;
}

class InvalidArchiveException implements Exception {
  const InvalidArchiveException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ArchiveService {
  ArchiveService(this.repo, {Directory? workDir}) : _workDir = workDir;

  final LibraryRepository repo;
  final Directory? _workDir;

  Future<Directory> _scratch(String name) async {
    final base = _workDir ?? await getTemporaryDirectory();
    final d = Directory(p.join(base.path, '$name-${DateTime.now().microsecondsSinceEpoch}'));
    await d.create(recursive: true);
    return d;
  }

  /// Builds an archive and returns its file. With [password], it's encrypted.
  Future<File> export({String? password, void Function(String stage, double progress)? onProgress}) async {
    final dir = await _scratch('export');
    final stamp = DateTime.now();
    final day = '${stamp.year}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}';
    final tarFile = File(p.join(dir.path, 'tibb-$day.tar'));

    final events = repo.log.allEvents();
    final blobs = <String, String?>{}; // hash -> mime
    for (final e in events) {
      if (e.op == Ops.itemCreate && e.payload['blobHash'] is String) {
        blobs[e.payload['blobHash']! as String] = e.payload['mime'] as String?;
      }
    }

    final writer = TarWriter(tarFile.openWrite());
    final manifest = {
      'format': kArchiveFormat,
      'version': kArchiveVersion,
      'exportedAt': stamp.toUtc().toIso8601String(),
      'deviceId': repo.deviceId,
      'events': events.length,
      'items': repo.itemCount(),
      'blobs': blobs.length,
      'app': 'Tibb',
    };
    await writer.addBytes('manifest.json', utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)));
    final jsonl = StringBuffer();
    for (final e in events) {
      jsonl.writeln(jsonEncode(e.toJson()));
    }
    await writer.addBytes('changes.jsonl', utf8.encode(jsonl.toString()));

    var i = 0;
    for (final entry in blobs.entries) {
      final f = repo.blobs.fileFor(entry.key, entry.value);
      // Blobs of deleted items may be gone already; import tolerates that.
      if (await f.exists()) await writer.addFile('blobs/${p.basename(f.path)}', f);
      i++;
      onProgress?.call('Packing', blobs.isEmpty ? 1 : i / blobs.length);
    }
    await writer.close();

    if (password == null || password.isEmpty) {
      final out = File(p.join(dir.path, 'tibb-$day.tibb'));
      return tarFile.rename(out.path);
    }
    final out = File(p.join(dir.path, 'tibb-$day-encrypted.tibb'));
    onProgress?.call('Encrypting', 0);
    await encryptFile(tarFile, out, password, onProgress: (v) => onProgress?.call('Encrypting', v));
    await tarFile.delete();
    return out;
  }

  Future<bool> needsPassword(File f) => isEncryptedArchive(f);

  Future<ImportResult> import(File file, {String? password, void Function(String stage, double progress)? onProgress}) async {
    final dir = await _scratch('import');
    try {
      var tar = file;
      if (await isEncryptedArchive(file)) {
        if (password == null) throw const WrongPasswordException();
        tar = File(p.join(dir.path, 'archive.tar'));
        await decryptFile(file, tar, password, onProgress: (v) => onProgress?.call('Decrypting', v));
      }

      Map<String, Object?>? manifest;
      final events = <ChangeEvent>[];
      final staged = <String, File>{}; // hash -> verified staged file
      final stagingDir = Directory(p.join(dir.path, 'blobs'))..createSync();

      try {
        await readTar(tar, (entry, data) async {
          if (entry.name == 'manifest.json') {
            manifest = Map<String, Object?>.from(jsonDecode(await utf8.decodeStream(data)) as Map);
          } else if (entry.name == 'changes.jsonl') {
            final lines = await data.transform(utf8.decoder).transform(const LineSplitter()).toList();
            for (final line in lines) {
              if (line.trim().isEmpty) continue;
              events.add(ChangeEvent.fromJson(Map<String, Object?>.from(jsonDecode(line) as Map)));
            }
          } else if (entry.name.startsWith('blobs/')) {
            final base = p.basename(entry.name);
            final hash = base.split('.').first;
            if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) return;
            final out = File(p.join(stagingDir.path, base));
            await data.pipe(out.openWrite());
            if (await BlobStore.hashFile(out) != hash) {
              throw InvalidArchiveException('A file in this archive is damaged ($base).');
            }
            staged[hash] = out;
          }
        });
      } on TarFormatException {
        throw const InvalidArchiveException("This isn't a Tibb export, or it's damaged.");
      } on FormatException {
        throw const InvalidArchiveException("This isn't a Tibb export, or it's damaged.");
      }

      final m = manifest;
      if (m == null || m['format'] != kArchiveFormat) {
        throw const InvalidArchiveException("This isn't a Tibb export.");
      }
      if ((m['version'] as num? ?? 0) > kArchiveVersion) {
        throw const InvalidArchiveException('This export was made by a newer Tibb. Update the app first.');
      }

      // Every blob a surviving item points at must be present (here or already on this phone).
      final alive = <String, String>{}; // itemId -> blobHash
      final mimes = <String, String?>{};
      for (final e in events) {
        switch (e.op) {
          case Ops.itemCreate:
            final h = e.payload['blobHash'];
            if (h is String) {
              alive[e.entityId] = h;
              mimes[h] = e.payload['mime'] as String?;
            }
          case Ops.itemDelete:
            alive.remove(e.entityId);
          default:
            break;
        }
      }
      for (final hash in alive.values.toSet()) {
        if (staged.containsKey(hash)) continue;
        if (await repo.blobs.exists(hash, mimes[hash])) continue;
        throw const InvalidArchiveException('This export is missing some files, so nothing was imported.');
      }

      // Move blobs into the store first: orphan blobs are harmless, missing ones are not.
      var moved = 0;
      for (final entry in staged.entries) {
        final mime = mimes[entry.key];
        final target = repo.blobs.fileFor(entry.key, mime);
        if (!await target.exists()) {
          await entry.value.copy(target.path);
          moved++;
        }
        final size = await target.length();
        repo.registerBlob(BlobRef(hash: entry.key, size: size, mime: mime ?? 'application/octet-stream', path: target.path));
      }

      onProgress?.call('Adding to your library', 1);
      final before = repo.itemCount();
      final applied = repo.applyForeignEvents(events);
      return ImportResult(newEvents: applied, newItems: repo.itemCount() - before, blobs: moved);
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
