// Content-addressed media storage (brief §8 principle 3). Every file is
// streamed to disk while being hashed (SHA-256), then renamed to its hash, so
// identical content is stored once and large files never sit in memory.
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class BlobRef {
  const BlobRef({required this.hash, required this.size, required this.mime, required this.path});
  final String hash;
  final int size;
  final String mime;
  final String path;
}

class StorageFullException implements Exception {
  const StorageFullException();
}

class BlobStore {
  BlobStore(this.root);

  /// Directory holding `<hash><ext>` files.
  final Directory root;

  Future<void> init() async {
    if (!await root.exists()) await root.create(recursive: true);
  }

  String pathFor(String hash, String? mime) => p.join(root.path, '$hash${extensionForMime(mime)}');

  File fileFor(String hash, String? mime) => File(pathFor(hash, mime));

  Future<bool> exists(String hash, String? mime) => fileFor(hash, mime).exists();

  /// Copies [source] into the store. [deleteSource] removes temp recordings etc.
  Future<BlobRef> ingestFile(File source, {required String mime, bool deleteSource = false}) async {
    final ref = await ingestStream(source.openRead(), mime: mime);
    if (deleteSource) {
      try {
        await source.delete();
      } catch (_) {/* best effort: the OS cleans temp directories */}
    }
    return ref;
  }

  /// Streams [data] into the store while hashing. Used by the Bridge upload
  /// endpoint so multi-gigabyte uploads never buffer in memory.
  Future<BlobRef> ingestStream(Stream<List<int>> data,
      {required String mime, void Function(int bytes)? onProgress}) async {
    await init();
    final tmp = File(p.join(root.path, '.incoming-${DateTime.now().microsecondsSinceEpoch}'));
    final sink = tmp.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var size = 0;
    try {
      await for (final chunk in data) {
        hasher.add(chunk);
        sink.add(chunk);
        size += chunk.length;
        onProgress?.call(size);
      }
      await sink.flush();
      await sink.close();
    } on FileSystemException catch (e) {
      await _safeDelete(tmp);
      // ENOSPC (28) — disk full. Anything else is rethrown as-is.
      if (e.osError?.errorCode == 28) throw const StorageFullException();
      rethrow;
    } catch (_) {
      await sink.close().catchError((_) {});
      await _safeDelete(tmp);
      rethrow;
    }
    hasher.close();
    final hash = digestSink.value.toString();
    final target = fileFor(hash, mime);
    if (await target.exists()) {
      await _safeDelete(tmp); // deduplicated
    } else {
      await tmp.rename(target.path);
    }
    return BlobRef(hash: hash, size: size, mime: mime, path: target.path);
  }

  /// Verifies a file's hash (used by import before trusting archive contents).
  static Future<String> hashFile(File f) async {
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    await for (final chunk in f.openRead()) {
      hasher.add(chunk);
    }
    hasher.close();
    return digestSink.value.toString();
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static String extensionForMime(String? mime) {
    switch (mime) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      case 'image/heif':
        return '.heif';
      case 'video/mp4':
        return '.mp4';
      case 'video/quicktime':
        return '.mov';
      case 'video/x-m4v':
        return '.m4v';
      case 'video/webm':
        return '.webm';
      case 'audio/mp4':
      case 'audio/x-m4a':
      case 'audio/m4a':
        return '.m4a';
      case 'audio/aac':
        return '.aac';
      case 'audio/mpeg':
        return '.mp3';
      case 'audio/wav':
        return '.wav';
      case 'audio/ogg':
        return '.ogg';
      case 'application/pdf':
        return '.pdf';
      case 'application/zip':
        return '.zip';
      case 'text/plain':
        return '.txt';
      default:
        return '.bin';
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}
