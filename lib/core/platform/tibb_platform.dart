// Dart side of Tibb's single native channel ("app.tibb/platform").
// Android implements it in MainActivity.kt with no third-party plugins:
// share-into-Tibb, local notifications and the Bridge foreground service.
// On iOS every call is a quiet no-op — the iPhone build has no Share
// Extension yet and keeps Bridge in the foreground (brief §7.2, §7.9).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One file handed to Tibb by another app, already copied into Tibb's cache.
class SharedFile {
  const SharedFile({required this.path, required this.name, required this.mime, required this.size});
  final String path;
  final String name;
  final String mime;
  final int size;

  bool get isImage => mime.startsWith('image/');
  bool get isVideo => mime.startsWith('video/');
  bool get isAudio => mime.startsWith('audio/');
  bool get isZip => mime == 'application/zip' || name.toLowerCase().endsWith('.zip');
  bool get isTibbArchive => name.toLowerCase().endsWith('.tibb');

  /// WhatsApp names its exports "WhatsApp Chat with … .zip" (and plain
  /// "_chat.txt" when media is left out).
  bool get looksLikeWhatsAppExport {
    final n = name.toLowerCase();
    return (isZip && n.contains('whatsapp')) || n == '_chat.txt' || n.startsWith('whatsapp chat');
  }
}

/// Everything one share action delivered.
class SharePayload {
  const SharePayload({this.text, this.subject, this.files = const [], this.failed = 0});
  final String? text;
  final String? subject;
  final List<SharedFile> files;

  /// Items the source app offered but Tibb couldn't read.
  final int failed;

  bool get isEmpty => (text == null || text!.trim().isEmpty) && files.isEmpty;

  static SharePayload? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final files = <SharedFile>[];
    for (final f in (raw['files'] as List?) ?? const []) {
      if (f is! Map) continue;
      final path = f['path'] as String?;
      if (path == null) continue;
      files.add(SharedFile(
        path: path,
        name: (f['name'] as String?) ?? path.split('/').last,
        mime: (f['mime'] as String?) ?? 'application/octet-stream',
        size: (f['size'] as num?)?.toInt() ?? 0,
      ));
    }
    final p = SharePayload(
      text: raw['text'] as String?,
      subject: raw['subject'] as String?,
      files: files,
      failed: (raw['failed'] as num?)?.toInt() ?? 0,
    );
    return p.isEmpty && p.failed == 0 ? null : p;
  }
}

/// Notification channels, as named in the design guide (§13.5).
enum TibbChannel {
  arrivals('from_computer'),
  bridge('bridge_status'),
  imports('imports');

  const TibbChannel(this.id);
  final String id;
}

class TibbPlatform {
  TibbPlatform._();
  static final TibbPlatform instance = TibbPlatform._();

  static const _channel = MethodChannel('app.tibb/platform');
  final _shares = StreamController<SharePayload>.broadcast();
  bool _initialized = false;

  /// Called when the Bridge notification's Stop button is pressed.
  VoidCallback? onBridgeStopRequested;

  bool get supported => !kIsWeb && Platform.isAndroid;

  /// Shares that arrive while Tibb is running.
  Stream<SharePayload> get shares => _shares.stream;

  void init() {
    if (_initialized || !supported) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onShare':
          final p = SharePayload.fromMap(call.arguments);
          if (p != null) _shares.add(p);
        case 'onBridgeStopRequested':
          onBridgeStopRequested?.call();
      }
      return null;
    });
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Tibb platform: $method failed: ${e.code}');
      return null;
    }
  }

  /// The share that cold-started Tibb, if any. Also tells the native side that
  /// Dart is listening, so later shares are pushed through [shares].
  Future<SharePayload?> takeInitialShare() async =>
      SharePayload.fromMap(await _invoke<Object?>('takeInitialShare'));

  /// Returns to the app the user shared from (design J2: auto-close after save).
  Future<void> moveToBack() => _invoke<bool>('moveToBack');

  Future<bool> notificationsAllowed() async => await _invoke<bool>('notificationsAllowed') ?? false;

  /// Android 13+ asks once; earlier versions are allowed by default.
  Future<bool> requestNotifications() async => await _invoke<bool>('requestNotifications') ?? false;

  Future<void> notify({
    required int id,
    required TibbChannel channel,
    required String title,
    required String body,
  }) =>
      _invoke<void>('notify', {'id': id, 'channel': channel.id, 'title': title, 'body': body});

  Future<void> startBridgeService({required String title, required String body}) =>
      _invoke<void>('startBridgeService', {'title': title, 'body': body});

  Future<void> stopBridgeService() => _invoke<void>('stopBridgeService');
}
