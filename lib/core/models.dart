// Domain models. Plain immutable classes; persistence lives in the repository.

enum ItemType {
  text,
  link,
  image,
  video,
  voice,
  file,
  clipboard;

  static ItemType fromName(String s) =>
      ItemType.values.firstWhere((t) => t.name == s, orElse: () => ItemType.text);

  /// Free tier: text and links (brief §9.1). Everything else is Pro to create.
  bool get isPro => this != text && this != link && this != clipboard;

  bool get hasBlob => this == image || this == video || this == voice || this == file;

  /// Maps a MIME type to the item type used for a saved file.
  static ItemType forMime(String mime) {
    if (mime.startsWith('image/')) return ItemType.image;
    if (mime.startsWith('video/')) return ItemType.video;
    if (mime.startsWith('audio/')) return ItemType.voice;
    return ItemType.file;
  }
}

class Box {
  const Box({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.locked,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.unreviewedCount = 0,
    this.lastPreview,
  });

  final String id;
  final String name;
  final String emoji;
  final String color; // BoxAccent name
  final bool locked;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Derived for list display.
  final int unreviewedCount;
  final String? lastPreview;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'locked': locked,
        'sortOrder': sortOrder,
        'unreviewed': unreviewedCount,
      };
}

class Item {
  const Item({
    required this.id,
    required this.boxId,
    required this.type,
    required this.originDeviceId,
    required this.createdAt,
    required this.updatedAt,
    this.text,
    this.blobHash,
    this.mime,
    this.fileName,
    this.size,
    this.durationMs,
    this.note,
    this.pinned = false,
    this.archived = false,
    this.reviewed = false,
    this.source,
    this.expiresAt,
    this.originDeviceName,
  });

  final String id;
  final String boxId;
  final ItemType type;
  final String? text;
  final String? blobHash;
  final String? mime;
  final String? fileName;
  final int? size;
  final int? durationMs;
  final String? note;
  final bool pinned;
  final bool archived;
  final bool reviewed;

  /// Where the item came from when it wasn't typed: e.g. "whatsapp".
  final String? source;
  final String originDeviceId;
  final String? originDeviceName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// One-line preview used in box lists, search and sheets.
  String get preview {
    switch (type) {
      case ItemType.text:
      case ItemType.link:
      case ItemType.clipboard:
        return (text ?? '').replaceAll('\n', ' ');
      case ItemType.image:
        return 'Photo';
      case ItemType.video:
        return 'Video';
      case ItemType.voice:
        return 'Voice memo';
      case ItemType.file:
        return fileName ?? 'File';
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'boxId': boxId,
        'type': type.name,
        'text': text,
        'blobHash': blobHash,
        'mime': mime,
        'fileName': fileName,
        'size': size,
        'durationMs': durationMs,
        'note': note,
        'pinned': pinned,
        'archived': archived,
        'reviewed': reviewed,
        'source': source,
        'origin': originDeviceId,
        'originName': originDeviceName,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
      };
}

class Device {
  const Device({required this.id, required this.name, required this.platform});
  final String id;
  final String name;
  final String platform; // 'ios', 'android', 'browser'
}

/// One append-only change-log event (brief §8). Current state is derived from
/// the log; exports are the log plus blobs.
class ChangeEvent {
  const ChangeEvent({
    required this.id,
    required this.deviceId,
    required this.counter,
    required this.ts,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payload,
    this.seq,
  });

  final String id;
  final int? seq;
  final String deviceId;
  final int counter;
  final int ts; // wall clock, ms since epoch
  final String entity; // 'box' | 'item' | 'device'
  final String entityId;
  final String op; // e.g. 'item.create'
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
        'id': id,
        'device': deviceId,
        'counter': counter,
        'ts': ts,
        'entity': entity,
        'entityId': entityId,
        'op': op,
        'payload': payload,
      };

  static ChangeEvent fromJson(Map<String, Object?> j) => ChangeEvent(
        id: j['id']! as String,
        deviceId: j['device']! as String,
        counter: (j['counter']! as num).toInt(),
        ts: (j['ts']! as num).toInt(),
        entity: j['entity']! as String,
        entityId: j['entityId']! as String,
        op: j['op']! as String,
        payload: Map<String, Object?>.from(j['payload']! as Map),
      );
}

/// Operation names. Kept as constants so the log format is greppable.
abstract final class Ops {
  static const deviceRegister = 'device.register';
  static const boxCreate = 'box.create';
  static const boxUpdate = 'box.update';
  static const boxDelete = 'box.delete';
  static const boxMarkReviewed = 'box.markReviewed';
  static const itemCreate = 'item.create';
  static const itemUpdate = 'item.update';
  static const itemDelete = 'item.delete';
  static const itemRestore = 'item.restore';
}
