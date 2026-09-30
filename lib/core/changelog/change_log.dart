// The change log (brief §8). Every mutation is an append-only event; the
// `boxes` / `items` tables are a materialized view of the log.
//
// Rules implemented here:
//  - Events are idempotent: re-applying an event with a known id is a no-op,
//    which makes import (and future Drive sync) safe to repeat.
//  - Deletes are tombstones (deleted_at), never row removals.
//  - Updates resolve last-write-wins per entity by event timestamp.
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../models.dart';
import '../util/ids.dart';

class ChangeLog {
  ChangeLog(this._db, {required this.deviceId});

  final Database _db;
  final String deviceId;

  int _counter() {
    final rows = _db.select("SELECT value FROM meta WHERE key = 'device_counter'");
    final current = rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String? ?? '0') ?? 0;
    final next = current + 1;
    _db.execute(
      "INSERT INTO meta (key, value) VALUES ('device_counter', ?) "
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [next.toString()],
    );
    return next;
  }

  /// Creates a new local event (authored by [authorDeviceId], defaulting to
  /// this phone) and applies it. Must be called inside [transaction].
  ChangeEvent record({
    required String entity,
    required String entityId,
    required String op,
    required Map<String, Object?> payload,
    String? authorDeviceId,
  }) {
    final e = ChangeEvent(
      id: newId(),
      deviceId: authorDeviceId ?? deviceId,
      counter: _counter(),
      ts: DateTime.now().millisecondsSinceEpoch,
      entity: entity,
      entityId: entityId,
      op: op,
      payload: payload,
    );
    apply(e);
    return e;
  }

  /// Applies an event (local or imported). Returns false if already known.
  bool apply(ChangeEvent e) {
    final exists = _db.select('SELECT 1 FROM changes WHERE id = ?', [e.id]);
    if (exists.isNotEmpty) return false;
    _db.execute(
      'INSERT INTO changes (id, device_id, counter, ts, entity, entity_id, op, payload) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [e.id, e.deviceId, e.counter, e.ts, e.entity, e.entityId, e.op, jsonEncode(e.payload)],
    );
    _materialize(e);
    return true;
  }

  void transaction(void Function() body) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      body();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  int get lastSeq {
    final r = _db.select('SELECT MAX(seq) AS s FROM changes');
    return (r.first['s'] as int?) ?? 0;
  }

  List<ChangeEvent> allEvents() {
    final rows = _db.select('SELECT * FROM changes ORDER BY seq ASC');
    return [for (final r in rows) _eventFromRow(r)];
  }

  List<ChangeEvent> eventsSince(int seq) {
    final rows = _db.select('SELECT * FROM changes WHERE seq > ? ORDER BY seq ASC LIMIT 500', [seq]);
    return [for (final r in rows) _eventFromRow(r)];
  }

  ChangeEvent _eventFromRow(Row r) => ChangeEvent(
        id: r['id'] as String,
        seq: r['seq'] as int,
        deviceId: r['device_id'] as String,
        counter: r['counter'] as int,
        ts: r['ts'] as int,
        entity: r['entity'] as String,
        entityId: r['entity_id'] as String,
        op: r['op'] as String,
        payload: Map<String, Object?>.from(jsonDecode(r['payload'] as String) as Map),
      );

  // ---------------------------------------------------------------------------
  // Materialization

  void _materialize(ChangeEvent e) {
    final p = e.payload;
    switch (e.op) {
      case Ops.deviceRegister:
        _db.execute(
          'INSERT INTO devices (id, name, platform, created_at) VALUES (?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET name = excluded.name',
          [e.entityId, p['name'], p['platform'] ?? 'browser', e.ts],
        );
      case Ops.boxCreate:
        _db.execute(
          'INSERT OR IGNORE INTO boxes (id, name, emoji, color, locked, sort_order, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            e.entityId,
            p['name'] ?? 'Box',
            p['emoji'] ?? '📦',
            p['color'] ?? 'saffron',
            (p['locked'] == true) ? 1 : 0,
            (p['sortOrder'] as num?)?.toInt() ?? 0,
            e.ts,
            e.ts,
          ],
        );
      case Ops.boxUpdate:
        _patch('boxes', e, const {
          'name': 'name',
          'emoji': 'emoji',
          'color': 'color',
          'locked': 'locked',
          'sortOrder': 'sort_order',
        });
      case Ops.boxDelete:
        _db.execute('UPDATE boxes SET deleted_at = ?, updated_at = ? WHERE id = ?',
            [e.ts, e.ts, e.entityId]);
        final ids = _db.select('SELECT id FROM items WHERE box_id = ? AND deleted_at IS NULL',
            [e.entityId]);
        _db.execute('UPDATE items SET deleted_at = ?, updated_at = ? WHERE box_id = ? AND deleted_at IS NULL',
            [e.ts, e.ts, e.entityId]);
        for (final r in ids) {
          _db.execute('DELETE FROM items_fts WHERE item_id = ?', [r['id']]);
        }
      case Ops.boxMarkReviewed:
        _db.execute(
            'UPDATE items SET reviewed = 1 WHERE box_id = ? AND reviewed = 0 AND created_at <= ?',
            [e.entityId, e.ts]);
      case Ops.itemCreate:
        _db.execute(
          'INSERT OR IGNORE INTO items (id, box_id, type, text, blob_hash, mime, file_name, size, '
          'duration_ms, note, pinned, archived, reviewed, source, origin_device_id, created_at, '
          'updated_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            e.entityId,
            p['boxId'],
            p['type'] ?? 'text',
            p['text'],
            p['blobHash'],
            p['mime'],
            p['fileName'],
            (p['size'] as num?)?.toInt(),
            (p['durationMs'] as num?)?.toInt(),
            p['note'],
            (p['pinned'] == true) ? 1 : 0,
            (p['archived'] == true) ? 1 : 0,
            (p['reviewed'] == true) ? 1 : 0,
            p['source'],
            e.deviceId,
            (p['createdAt'] as num?)?.toInt() ?? e.ts,
            e.ts,
            (p['expiresAt'] as num?)?.toInt(),
          ],
        );
        _reindex(e.entityId);
      case Ops.itemUpdate:
        _patch('items', e, const {
          'boxId': 'box_id',
          'text': 'text',
          'note': 'note',
          'pinned': 'pinned',
          'archived': 'archived',
          'reviewed': 'reviewed',
        });
        _reindex(e.entityId);
      case Ops.itemDelete:
        _db.execute('UPDATE items SET deleted_at = ?, updated_at = ? WHERE id = ?',
            [e.ts, e.ts, e.entityId]);
        _db.execute('DELETE FROM items_fts WHERE item_id = ?', [e.entityId]);
      case Ops.itemRestore:
        _db.execute('UPDATE items SET deleted_at = NULL, updated_at = ? WHERE id = ?',
            [e.ts, e.entityId]);
        _reindex(e.entityId);
    }
  }

  /// Applies a field patch if this event is not older than the entity's last
  /// write (last-write-wins by timestamp).
  void _patch(String table, ChangeEvent e, Map<String, String> fieldToColumn) {
    final current = _db.select('SELECT updated_at FROM $table WHERE id = ?', [e.entityId]);
    if (current.isEmpty) return;
    final updatedAt = current.first['updated_at'] as int;
    if (e.ts < updatedAt) return;

    final sets = <String>[];
    final values = <Object?>[];
    e.payload.forEach((key, value) {
      final column = fieldToColumn[key];
      if (column == null) return;
      sets.add('$column = ?');
      values.add(value is bool ? (value ? 1 : 0) : value);
    });
    if (sets.isEmpty) return;
    sets.add('updated_at = ?');
    values
      ..add(e.ts)
      ..add(e.entityId);
    _db.execute('UPDATE $table SET ${sets.join(', ')} WHERE id = ?', values);
  }

  /// Keeps the full-text index in step with the item (text, note, file name).
  /// Clipboard items are excluded from long-term search (brief §7.10).
  void _reindex(String itemId) {
    _db.execute('DELETE FROM items_fts WHERE item_id = ?', [itemId]);
    final r = _db.select(
        'SELECT type, text, note, file_name, deleted_at FROM items WHERE id = ?', [itemId]);
    if (r.isEmpty) return;
    final row = r.first;
    if (row['deleted_at'] != null || row['type'] == 'clipboard') return;
    final content = [row['text'], row['note'], row['file_name']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join('\n');
    if (content.isEmpty) return;
    _db.execute('INSERT INTO items_fts (item_id, content) VALUES (?, ?)', [itemId, content]);
  }
}
