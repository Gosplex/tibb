// WhatsApp self-chat import (brief §7.12) — the one implementation shared by
// the phone's import screen and the Bridge page on the computer, so both go
// through the same parser, the same duplicate check and the same repository
// writes.
//
// Everything happens on this phone. The export is unpacked into a temp folder,
// parsed in a background isolate, and deleted afterwards.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../core/blobs/blob_store.dart';
import '../../core/models.dart';
import '../../core/platform/tibb_platform.dart';
import '../../core/repository/library_repository.dart';
import '../../core/util/format.dart';
import 'whatsapp_parser.dart';

enum WaImportError { notWhatsApp, empty, storageFull, failed }

class WaImportException implements Exception {
  const WaImportException(this.kind);
  final WaImportError kind;

  /// Plain-language message (design §11.4: no blame, always a way forward).
  String get message => switch (kind) {
        WaImportError.notWhatsApp =>
          "This doesn't look like a WhatsApp export. Export the chat again with “Include media” and choose the .zip.",
        WaImportError.empty => 'That export has no messages Tibb can bring over.',
        WaImportError.storageFull => 'Your phone is out of space. Free some up, then try again — nothing was lost.',
        WaImportError.failed => "Something went wrong reading the export. Nothing was imported. Try again.",
      };
}

/// An unpacked, parsed export waiting for the user's confirmation.
class WaPrepared {
  WaPrepared._(this._raw, this.workDir, this.media, this.result, this.sourceName);

  final String _raw;
  final Directory workDir;

  /// Attachment file name → extracted path.
  final Map<String, String> media;
  final String sourceName;
  WaParseResult result;

  bool get dayFirst => result.dayFirst;

  /// Re-reads the chat with the other date order (the preview's toggle).
  Future<void> setDayFirst(bool value) async {
    if (value == result.dayFirst && result.dateOrderCertain) return;
    result = await compute(_parseEntry, (_raw, value));
  }

  int get mediaAvailable => result.messages.where((m) => m.attachment != null && media.containsKey(m.attachment)).length;

  /// First few text messages, for the "Look right?" date check.
  List<WaMessage> samples([int n = 3]) =>
      result.messages.where((m) => m.attachment == null && m.text.trim().isNotEmpty).take(n).toList();

  Future<void> dispose() async {
    try {
      if (await workDir.exists()) await workDir.delete(recursive: true);
    } catch (_) {/* temp folder: the OS cleans it anyway */}
  }
}

class WaImportSummary {
  const WaImportSummary({
    required this.created,
    required this.duplicates,
    required this.missingMedia,
    required this.boxId,
    required this.boxName,
    required this.archived,
  });

  final int created;
  final int duplicates;
  final int missingMedia;
  final String boxId;
  final String boxName;
  final bool archived;

  Map<String, Object?> toJson() => {
        'created': created,
        'duplicates': duplicates,
        'missingMedia': missingMedia,
        'boxId': boxId,
        'boxName': boxName,
        'archived': archived,
      };
}

WaParseResult _parseEntry((String, bool?) args) => parseWhatsApp(args.$1, dayFirst: args.$2);

class WhatsAppImporter {
  WhatsAppImporter(this.repo);

  final LibraryRepository repo;

  static const boxName = 'WhatsApp import';
  static const source = 'whatsapp';

  /// Unpacks a `.zip` export (or a bare `_chat.txt`) into [parent] and parses it.
  static Future<WaPrepared> prepare(File file, {required Directory parent, String? displayName}) async {
    final dir = Directory(p.join(parent.path, 'wa-${DateTime.now().microsecondsSinceEpoch}'));
    await dir.create(recursive: true);
    final media = <String, String>{};
    try {
      String? chat;
      final name = (displayName ?? p.basename(file.path)).toLowerCase();
      if (name.endsWith('.txt')) {
        chat = await file.readAsString().catchError((Object _) => '');
      } else {
        chat = await _unzip(file, dir, media);
      }
      if (chat == null || chat.trim().isEmpty) throw const WaImportException(WaImportError.notWhatsApp);
      final result = await compute(_parseEntry, (chat, null));
      if (result.messages.isEmpty) throw const WaImportException(WaImportError.notWhatsApp);
      return WaPrepared._(chat, dir, media, result, displayName ?? p.basename(file.path));
    } on WaImportException {
      await _cleanup(dir);
      rethrow;
    } on FileSystemException catch (e) {
      await _cleanup(dir);
      throw WaImportException(e.osError?.errorCode == 28 ? WaImportError.storageFull : WaImportError.failed);
    } catch (_) {
      await _cleanup(dir);
      throw const WaImportException(WaImportError.notWhatsApp);
    }
  }

  static Future<void> _cleanup(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Streams each entry to disk (one entry in memory at a time) and returns the chat text.
  static Future<String?> _unzip(File zip, Directory dir, Map<String, String> media) async {
    final input = InputFileStream(zip.path);
    try {
      final archive = ZipDecoder().decodeBuffer(input);
      String? chat;
      var chatIsCanonical = false;
      for (final f in archive.files) {
        if (!f.isFile) continue;
        final base = p.basename(f.name);
        if (base.isEmpty || base.startsWith('.') || f.name.contains('__MACOSX')) continue;
        final lower = base.toLowerCase();
        if (lower.endsWith('.txt') && !chatIsCanonical) {
          // `_chat.txt` on iPhone; "WhatsApp Chat with … .txt" on Android.
          final bytes = f.content as List<int>;
          chat = utf8.decode(bytes, allowMalformed: true);
          chatIsCanonical = lower == '_chat.txt';
          continue;
        }
        final target = p.join(dir.path, base);
        final out = OutputFileStream(target);
        try {
          f.writeContent(out);
        } finally {
          await out.close();
        }
        media[base] = target;
      }
      return chat;
    } finally {
      await input.close();
    }
  }

  /// Imports the chosen senders' messages. Returns what happened; throws
  /// [WaImportException] on storage failure. [isCancelled] is checked between
  /// batches so a cancel stops cleanly with everything so far kept.
  Future<WaImportSummary> run(
    WaPrepared prepared, {
    required Set<String> senders,
    required bool includeMedia,
    required bool isPro,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final result = prepared.result;
    final chosen = result.messages.where((m) => senders.contains(m.sender)).toList();
    final withMedia = includeMedia && isPro;

    // Pro: a dedicated box (reused on re-import) keeps years of history out of
    // the everyday thread. Free has one box, so the history goes into its
    // archive — searchable, never in the way.
    final Box box;
    final archived = !isPro;
    if (isPro) {
      box = repo.boxes().where((b) => b.name == boxName && !b.locked).firstOrNull ??
          repo.createBox(name: boxName, emoji: '💬', color: 'teal');
    } else {
      box = repo.box(repo.defaultBoxId)!;
    }

    final existing = repo.importedKeys(source);
    final prefix = senders.length > 1;
    final texts = <Map<String, Object?>>[];
    final media = <WaMessage>[];
    var duplicates = 0;
    var missing = 0;

    for (final m in chosen) {
      if (m.attachment != null) {
        if (!withMedia) continue;
        if (!prepared.media.containsKey(m.attachment)) {
          missing++;
          continue;
        }
        if (existing.contains(_mediaKey(m))) {
          duplicates++;
          continue;
        }
        media.add(m);
        continue;
      }
      final text = m.text.trim();
      if (text.isEmpty) continue;
      final body = prefix ? '${m.sender}: $text' : text;
      final key = '${m.time.millisecondsSinceEpoch}|$body';
      if (existing.contains(key)) {
        duplicates++;
        continue;
      }
      existing.add(key);
      texts.add({
        'boxId': box.id,
        'type': isSingleUrl(text) ? 'link' : 'text',
        'text': body,
        'createdAt': m.time.millisecondsSinceEpoch,
        'reviewed': true,
        if (archived) 'archived': true,
      });
    }

    final total = texts.length + media.length;
    var done = 0;
    var created = 0;
    onProgress?.call(0, total);

    // Text in batches: one transaction each, with a frame between them so the
    // progress bar moves and the UI never freezes on a big history.
    const batch = 400;
    for (var i = 0; i < texts.length; i += batch) {
      if (isCancelled?.call() ?? false) break;
      final slice = texts.sublist(i, i + batch > texts.length ? texts.length : i + batch);
      created += repo.addMany(slice, source: source);
      done += slice.length;
      onProgress?.call(done, total);
      await Future<void>.delayed(Duration.zero);
    }

    for (final m in media) {
      if (isCancelled?.call() ?? false) break;
      final path = prepared.media[m.attachment]!;
      final mime = mimeFromName(m.attachment!);
      try {
        final blob = await repo.blobs.ingestFile(File(path), mime: mime, deleteSource: true);
        repo.addBlob(box.id, blob,
            fileName: m.attachment!,
            type: ItemType.forMime(mime),
            source: source,
            createdAt: m.time,
            archived: archived);
        created++;
      } on StorageFullException {
        throw const WaImportException(WaImportError.storageFull);
      } catch (_) {
        missing++;
      }
      done++;
      onProgress?.call(done, total);
    }

    repo.markBoxReviewed(box.id);
    return WaImportSummary(
      created: created,
      duplicates: duplicates,
      missingMedia: missing,
      boxId: box.id,
      boxName: box.name,
      archived: archived,
    );
  }

  static String _mediaKey(WaMessage m) => '${m.time.millisecondsSinceEpoch}|file:${m.attachment}';

  /// "Imported 1,284 items from WhatsApp" — only when Tibb isn't on screen,
  /// because on screen the done view already says it (events, not nagging).
  static void notifyIfBackground(int created) {
    if (created <= 0) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.resumed) return;
    unawaited(TibbPlatform.instance.notify(
      id: 3100,
      channel: TibbChannel.imports,
      title: 'Imported ${formatCount(created)} item${created == 1 ? '' : 's'} from WhatsApp',
      body: 'They’re on this phone now.',
    ));
  }
}
