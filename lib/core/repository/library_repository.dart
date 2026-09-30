// LibraryRepository — the single data API for Tibb. The Flutter UI, the Bridge
// server and import/export all go through it, so an item saved from a PC takes
// exactly the same path as one saved on the phone (brief §10, key notes).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../blobs/blob_store.dart';
import '../changelog/change_log.dart';
import '../db/database.dart';
import '../models.dart';
import '../util/format.dart';
import '../util/ids.dart';

enum SearchFilter { all, text, links, media, files, voice }

class SearchResult {
  const SearchResult(this.item, this.box);
  final Item item;
  final Box box;
}

class LibraryRepository extends ChangeNotifier {
  LibraryRepository._(this._db, this.blobs, this.log, this.deviceId, this.deviceName);

  final Database _db;
  final BlobStore blobs;
  final ChangeLog log;
  final String deviceId;
  final String deviceName;

  final _changes = StreamController<ChangeEvent>.broadcast();

  /// Every applied event, local or from a Bridge browser. Bridge long-polls on this.
  Stream<ChangeEvent> get changes => _changes.stream;

  final Map<String, String> _deviceNames = {};

  static Future<LibraryRepository> open() async {
    final support = await getApplicationSupportDirectory();
    final db = openTibbDatabase(p.join(support.path, 'tibb.sqlite'));
    final blobs = BlobStore(Directory(p.join(support.path, 'blobs')));
    await blobs.init();
    return _bootstrap(db, blobs, platform: Platform.isIOS ? 'ios' : 'android');
  }

  /// Test/dev entry point with an injected database and blob directory.
  @visibleForTesting
  static Future<LibraryRepository> openWith(Database db, BlobStore blobs) =>
      _bootstrap(db, blobs, platform: 'test');

  static Future<LibraryRepository> _bootstrap(Database db, BlobStore blobs,
      {required String platform}) async {
    String? meta(String k) {
      final r = db.select('SELECT value FROM meta WHERE key = ?', [k]);
      return r.isEmpty ? null : r.first['value'] as String?;
    }

    final existing = meta('device_id');
    final isFirstRun = existing == null;
    final id = existing ?? newId();
    // Stored name for this device in the log; UI says "this phone" for our own items.
    final name = switch (platform) { 'ios' => 'iPhone', 'android' => 'Android phone', _ => 'Test device' };
    final log = ChangeLog(db, deviceId: id);
    final repo = LibraryRepository._(db, blobs, log, id, name);

    if (isFirstRun) {
      repo.setMeta('device_id', id);
      log.transaction(() {
        log.record(
          entity: 'device',
          entityId: id,
          op: Ops.deviceRegister,
          payload: {'name': name, 'platform': platform},
        );
        final boxId = newId();
        log.record(
          entity: 'box',
          entityId: boxId,
          op: Ops.boxCreate,
          payload: {'name': 'Personal', 'emoji': '📦', 'color': 'saffron', 'sortOrder': 0},
        );
        // The seeded item (design §13.3): a real, deletable item, not a tutorial card.
        log.record(
          entity: 'item',
          entityId: newId(),
          op: Ops.itemCreate,
          payload: {
            'boxId': boxId,
            'type': 'text',
            'text': 'This is your box. Anything you save lands here: on this phone only. '
                'Try typing something below.',
            'reviewed': true,
          },
        );
      });
      repo.setMeta('default_box', repo.boxes().first.id);
    }
    repo._loadDeviceNames();
    return repo;
  }

  // ---------------------------------------------------------------------------
  // Meta (settings & one-time flags)

  String? getMeta(String key) {
    final r = _db.select('SELECT value FROM meta WHERE key = ?', [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  void setMeta(String key, String value) {
    _db.execute(
      'INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  bool flag(String key) => getMeta(key) == '1';
  void setFlag(String key) => setMeta(key, '1');

  int incrementCounter(String key) {
    final n = (int.tryParse(getMeta(key) ?? '0') ?? 0) + 1;
    setMeta(key, '$n');
    return n;
  }

  // ---------------------------------------------------------------------------
  // Devices

  void _loadDeviceNames() {
    for (final r in _db.select('SELECT id, name FROM devices')) {
      _deviceNames[r['id'] as String] = r['name'] as String;
    }
  }

  String deviceNameFor(String id) => _deviceNames[id] ?? 'Another device';

  bool isThisDevice(String id) => id == deviceId;

  /// Registers (or renames) a Bridge browser as a device in the log.
  void registerDevice(String id, String name, {String platform = 'browser'}) {
    _write(() => log.record(
          entity: 'device',
          entityId: id,
          op: Ops.deviceRegister,
          payload: {'name': name, 'platform': platform},
        ));
    _deviceNames[id] = name;
  }

  // ---------------------------------------------------------------------------
  // Reads

  List<Box> boxes() {
    final rows = _db.select('''
      SELECT b.*,
        (SELECT COUNT(*) FROM items i WHERE i.box_id = b.id AND i.deleted_at IS NULL
           AND i.archived = 0 AND i.reviewed = 0 AND i.type != 'clipboard') AS unreviewed,
        (SELECT i.type || char(31) || COALESCE(i.text, i.file_name, '') FROM items i
           WHERE i.box_id = b.id AND i.deleted_at IS NULL AND i.type != 'clipboard'
           ORDER BY i.created_at DESC LIMIT 1) AS last_preview
      FROM boxes b WHERE b.deleted_at IS NULL ORDER BY b.sort_order ASC, b.created_at ASC
    ''');
    return [for (final r in rows) _boxFromRow(r)];
  }

  Box? box(String id) {
    final rows = _db.select('SELECT * FROM boxes WHERE id = ? AND deleted_at IS NULL', [id]);
    return rows.isEmpty ? null : _boxFromRow(rows.first);
  }

  String get defaultBoxId {
    final stored = getMeta('default_box');
    if (stored != null && box(stored) != null) return stored;
    return boxes().first.id;
  }

  /// Newest first. Clipboard items are excluded — they render as the pinned card.
  List<Item> items(String boxId, {bool archived = false, int limit = 300}) {
    final rows = _db.select(
      'SELECT * FROM items WHERE box_id = ? AND deleted_at IS NULL AND archived = ? '
      "AND type != 'clipboard' ORDER BY pinned DESC, created_at DESC LIMIT ?",
      [boxId, archived ? 1 : 0, limit],
    );
    return [for (final r in rows) _itemFromRow(r)];
  }

  Item? item(String id) {
    final rows = _db.select('SELECT * FROM items WHERE id = ?', [id]);
    return rows.isEmpty ? null : _itemFromRow(rows.first);
  }

  /// Latest unexpired clipboard item (from either side of Bridge).
  Item? latestClipboard() {
    final rows = _db.select(
      "SELECT * FROM items WHERE type = 'clipboard' AND deleted_at IS NULL "
      'AND (expires_at IS NULL OR expires_at > ?) ORDER BY created_at DESC LIMIT 1',
      [DateTime.now().millisecondsSinceEpoch],
    );
    return rows.isEmpty ? null : _itemFromRow(rows.first);
  }

  /// MIME type recorded for a blob (Bridge uses it to serve media correctly).
  String? blobMime(String hash) {
    final r = _db.select('SELECT mime FROM blobs WHERE hash = ?', [hash]);
    return r.isEmpty ? null : r.first['mime'] as String?;
  }

  /// True if any live item references [hash] (Bridge only serves referenced blobs).
  bool isBlobReferenced(String hash) =>
      _db.select('SELECT 1 FROM items WHERE blob_hash = ? AND deleted_at IS NULL LIMIT 1', [hash])
          .isNotEmpty;

  List<String> referencedBlobs() => [
        for (final r in _db.select(
            'SELECT DISTINCT blob_hash, mime FROM items WHERE blob_hash IS NOT NULL AND deleted_at IS NULL'))
          r['blob_hash'] as String
      ];

  /// Keys of items already brought in from [source] (e.g. "whatsapp"), so a
  /// re-import skips what's there: "<createdAt>|<text>" or "<createdAt>|file:<name>".
  Set<String> importedKeys(String source) {
    final rows = _db.select(
      'SELECT created_at, type, text, file_name FROM items WHERE source = ? AND deleted_at IS NULL',
      [source],
    );
    return {
      for (final r in rows)
        (r['file_name'] != null && r['type'] != 'text' && r['type'] != 'link')
            ? '${r['created_at']}|file:${r['file_name']}'
            : '${r['created_at']}|${r['text'] ?? ''}'
    };
  }

  /// Count of archived items in a box (the WhatsApp done screen offers to unarchive them).
  int archivedCount(String boxId) => _db.select(
        'SELECT COUNT(*) AS n FROM items WHERE box_id = ? AND archived = 1 AND deleted_at IS NULL',
        [boxId],
      ).first['n'] as int;

  int itemCount() =>
      (_db.select('SELECT COUNT(*) AS n FROM items WHERE deleted_at IS NULL').first['n'] as int);

  /// Full-text search. Locked boxes are skipped unless listed in [unlockedBoxIds]
  /// (design RULE: locked content is absent, not blurred).
  List<SearchResult> search(String query,
      {SearchFilter filter = SearchFilter.all, Set<String> unlockedBoxIds = const {}}) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*')
        .join(' ');
    if (terms.isEmpty) return const [];

    final typeClause = switch (filter) {
      SearchFilter.all => '',
      SearchFilter.text => "AND i.type = 'text'",
      SearchFilter.links => "AND (i.type = 'link' OR i.text LIKE '%http%')",
      SearchFilter.media => "AND i.type IN ('image', 'video')",
      SearchFilter.files => "AND i.type = 'file'",
      SearchFilter.voice => "AND i.type = 'voice'",
    };

    final ResultSet rows;
    try {
      rows = _db.select('''
        SELECT i.* FROM items_fts f JOIN items i ON i.id = f.item_id
        JOIN boxes b ON b.id = i.box_id AND b.deleted_at IS NULL
        WHERE items_fts MATCH ? AND i.deleted_at IS NULL $typeClause
        ORDER BY i.archived ASC, rank LIMIT 100
      ''', [terms]);
    } on SqliteException {
      return const []; // malformed query from odd punctuation: treat as no results
    }

    final boxById = {for (final b in boxes()) b.id: b};
    final out = <SearchResult>[];
    for (final r in rows) {
      final item = _itemFromRow(r);
      final b = boxById[item.boxId];
      if (b == null) continue;
      if (b.locked && !unlockedBoxIds.contains(b.id)) continue;
      out.add(SearchResult(item, b));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Writes (all through the change log)

  void _write(void Function() body) {
    final before = log.lastSeq;
    log.transaction(body);
    notifyListeners();
    for (final e in log.eventsSince(before)) {
      _changes.add(e);
    }
  }

  Box createBox({required String name, required String emoji, required String color}) {
    final id = newId();
    final order = boxes().length;
    _write(() => log.record(
          entity: 'box',
          entityId: id,
          op: Ops.boxCreate,
          payload: {'name': name, 'emoji': emoji, 'color': color, 'sortOrder': order},
        ));
    return box(id)!;
  }

  void updateBox(String id, {String? name, String? emoji, String? color, bool? locked, int? sortOrder}) {
    final patch = <String, Object?>{
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (color != null) 'color': color,
      if (locked != null) 'locked': locked,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
    if (patch.isEmpty) return;
    _write(() => log.record(entity: 'box', entityId: id, op: Ops.boxUpdate, payload: patch));
  }

  void reorderBoxes(List<String> orderedIds) {
    _write(() {
      for (var i = 0; i < orderedIds.length; i++) {
        log.record(entity: 'box', entityId: orderedIds[i], op: Ops.boxUpdate, payload: {'sortOrder': i});
      }
    });
  }

  void deleteBox(String id) {
    if (boxes().length <= 1) return; // one box always exists
    _write(() => log.record(entity: 'box', entityId: id, op: Ops.boxDelete, payload: const {}));
    if (getMeta('default_box') == id) setMeta('default_box', boxes().first.id);
  }

  void markBoxReviewed(String boxId) {
    final pending = _db.select(
        "SELECT 1 FROM items WHERE box_id = ? AND reviewed = 0 AND deleted_at IS NULL LIMIT 1",
        [boxId]);
    if (pending.isEmpty) return;
    _write(() => log.record(entity: 'box', entityId: boxId, op: Ops.boxMarkReviewed, payload: const {}));
  }

  /// Saves typed/pasted text. A lone URL becomes a link item.
  Item addText(String boxId, String text, {String? authorDeviceId}) {
    final trimmed = text.trim();
    return _createItem(
      boxId: boxId,
      payload: {'type': isSingleUrl(trimmed) ? 'link' : 'text', 'text': trimmed},
      authorDeviceId: authorDeviceId,
    );
  }

  Item addClipboard(String text, {String? boxId, String? authorDeviceId}) => _createItem(
        boxId: boxId ?? defaultBoxId,
        payload: {
          'type': 'clipboard',
          'text': text,
          'pinned': true,
          'expiresAt': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
        },
        authorDeviceId: authorDeviceId,
      );

  Item addBlob(String boxId, BlobRef blob,
      {required String fileName,
      ItemType? type,
      int? durationMs,
      String? authorDeviceId,
      String? source,
      DateTime? createdAt,
      bool archived = false,
      String? text}) {
    _db.execute('INSERT OR IGNORE INTO blobs (hash, mime, size, created_at) VALUES (?, ?, ?, ?)',
        [blob.hash, blob.mime, blob.size, DateTime.now().millisecondsSinceEpoch]);
    return _createItem(
      boxId: boxId,
      authorDeviceId: authorDeviceId,
      payload: {
        'type': (type ?? ItemType.forMime(blob.mime)).name,
        'blobHash': blob.hash,
        'mime': blob.mime,
        'fileName': fileName,
        'size': blob.size,
        if (durationMs != null) 'durationMs': durationMs,
        if (source != null) 'source': source,
        if (createdAt != null) 'createdAt': createdAt.millisecondsSinceEpoch,
        if (archived) 'archived': true,
        if (text != null) 'text': text,
      },
    );
  }

  Item _createItem({required String boxId, required Map<String, Object?> payload, String? authorDeviceId}) {
    final id = newId();
    _write(() => log.record(
          entity: 'item',
          entityId: id,
          op: Ops.itemCreate,
          payload: {'boxId': boxId, ...payload},
          authorDeviceId: authorDeviceId,
        ));
    return item(id)!;
  }

  /// Bulk create in one transaction (WhatsApp import). Returns count created.
  int addMany(List<Map<String, Object?>> payloads, {String? source}) {
    var n = 0;
    _write(() {
      for (final pl in payloads) {
        log.record(
          entity: 'item',
          entityId: newId(),
          op: Ops.itemCreate,
          payload: {...pl, if (source != null) 'source': source},
        );
        n++;
      }
    });
    return n;
  }

  void registerBlob(BlobRef blob) {
    _db.execute('INSERT OR IGNORE INTO blobs (hash, mime, size, created_at) VALUES (?, ?, ?, ?)',
        [blob.hash, blob.mime, blob.size, DateTime.now().millisecondsSinceEpoch]);
  }

  void updateItem(String id,
      {String? text, String? note, bool? pinned, bool? archived, String? boxId, String? authorDeviceId}) {
    final patch = <String, Object?>{
      if (text != null) 'text': text,
      if (note != null) 'note': note,
      if (pinned != null) 'pinned': pinned,
      if (archived != null) 'archived': archived,
      if (boxId != null) 'boxId': boxId,
    };
    if (patch.isEmpty) return;
    _write(() => log.record(
        entity: 'item', entityId: id, op: Ops.itemUpdate, payload: patch, authorDeviceId: authorDeviceId));
  }

  void deleteItem(String id) =>
      _write(() => log.record(entity: 'item', entityId: id, op: Ops.itemDelete, payload: const {}));

  /// Reverses a delete (undo toast). A separate event, so the log records both
  /// the delete and the restore.
  void restoreItem(String id) =>
      _write(() => log.record(entity: 'item', entityId: id, op: Ops.itemRestore, payload: const {}));

  /// Archives items older than [before] in a box (bulk triage).
  int archiveOlderThan(String boxId, DateTime before) {
    final rows = _db.select(
      'SELECT id FROM items WHERE box_id = ? AND archived = 0 AND deleted_at IS NULL AND created_at < ?',
      [boxId, before.millisecondsSinceEpoch],
    );
    if (rows.isEmpty) return 0;
    _write(() {
      for (final r in rows) {
        log.record(entity: 'item', entityId: r['id'] as String, op: Ops.itemUpdate, payload: {'archived': true});
      }
    });
    return rows.length;
  }

  void unarchiveAll(String boxId) {
    final rows = _db.select(
        'SELECT id FROM items WHERE box_id = ? AND archived = 1 AND deleted_at IS NULL', [boxId]);
    if (rows.isEmpty) return;
    _write(() {
      for (final r in rows) {
        log.record(entity: 'item', entityId: r['id'] as String, op: Ops.itemUpdate, payload: {'archived': false});
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Import (idempotent replay of foreign events)

  /// Applies events from an archive in one transaction. Returns how many were new.
  int applyForeignEvents(List<ChangeEvent> events) {
    var applied = 0;
    _write(() {
      for (final e in events) {
        if (log.apply(e)) applied++;
      }
    });
    _loadDeviceNames();
    return applied;
  }

  // ---------------------------------------------------------------------------
  // Row mapping

  Box _boxFromRow(Row r) {
    String? preview;
    final raw = r.containsKey('last_preview') ? r['last_preview'] as String? : null;
    if (raw != null) {
      final parts = raw.split(String.fromCharCode(31));
      final type = ItemType.fromName(parts.first);
      final body = parts.length > 1 ? parts[1] : '';
      preview = switch (type) {
        ItemType.image => 'Photo',
        ItemType.video => 'Video',
        ItemType.voice => 'Voice memo',
        _ => body.replaceAll('\n', ' '),
      };
    }
    return Box(
      id: r['id'] as String,
      name: r['name'] as String,
      emoji: r['emoji'] as String,
      color: r['color'] as String,
      locked: (r['locked'] as int) == 1,
      sortOrder: r['sort_order'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
      unreviewedCount: r.containsKey('unreviewed') ? (r['unreviewed'] as int? ?? 0) : 0,
      lastPreview: preview,
    );
  }

  Item _itemFromRow(Row r) {
    final origin = r['origin_device_id'] as String;
    final expires = r['expires_at'] as int?;
    return Item(
      id: r['id'] as String,
      boxId: r['box_id'] as String,
      type: ItemType.fromName(r['type'] as String),
      text: r['text'] as String?,
      blobHash: r['blob_hash'] as String?,
      mime: r['mime'] as String?,
      fileName: r['file_name'] as String?,
      size: r['size'] as int?,
      durationMs: r['duration_ms'] as int?,
      note: r['note'] as String?,
      pinned: (r['pinned'] as int) == 1,
      archived: (r['archived'] as int) == 1,
      reviewed: (r['reviewed'] as int) == 1,
      source: r['source'] as String?,
      originDeviceId: origin,
      originDeviceName: origin == deviceId ? null : deviceNameFor(origin),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
      expiresAt: expires == null ? null : DateTime.fromMillisecondsSinceEpoch(expires),
    );
  }

  @override
  void dispose() {
    _changes.close();
    _db.dispose();
    super.dispose();
  }
}
