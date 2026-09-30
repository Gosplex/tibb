// Local notifications for things that actually happened (brief §7.14):
//   "Saved from Chrome on Windows"          (batched per 10 s, design §13.5)
//   "Clipboard from your PC — tap to copy"   (immediately, it's actionable)
// Never about absence, never streaks, never a badge on the app icon.
import 'dart:async';

import '../../core/models.dart';
import '../../core/platform/tibb_platform.dart';
import '../../core/repository/library_repository.dart';
import 'bridge_server.dart';

class ArrivalNotifier {
  ArrivalNotifier(this._repo, this._bridge, {TibbPlatform? platform})
      : _platform = platform ?? TibbPlatform.instance {
    _sub = _repo.changes.listen(_onChange);
  }

  final LibraryRepository _repo;
  final BridgeServer _bridge;
  final TibbPlatform _platform;
  late final StreamSubscription<ChangeEvent> _sub;

  static const _window = Duration(seconds: 10);
  static const _savesId = 3001;
  static const _clipboardId = 3002;

  final Map<String, int> _pending = {};
  final Map<String, String> _lastKind = {};
  Timer? _flush;

  void _onChange(ChangeEvent e) {
    if (e.op != Ops.itemCreate) return;
    if (_repo.isThisDevice(e.deviceId)) return;
    // Only live Bridge arrivals notify; imported history never does.
    if (!_bridge.isConnected || e.deviceId != _bridge.session?.deviceId) return;
    final name = _repo.deviceNameFor(e.deviceId);
    if (e.payload['type'] == 'clipboard') {
      _platform.notify(
        id: _clipboardId,
        channel: TibbChannel.arrivals,
        title: 'Clipboard from your computer',
        body: 'Tap to open Tibb and copy it.',
      );
      return;
    }
    _pending[name] = (_pending[name] ?? 0) + 1;
    _lastKind[name] = _kindLabel(e.payload);
    _flush ??= Timer(_window, _send);
  }

  String _kindLabel(Map<String, Object?> p) => switch (p['type']) {
        'image' => 'A photo',
        'video' => 'A video',
        'voice' => 'A voice memo',
        'file' => (p['fileName'] as String?) ?? 'A file',
        'link' => 'A link',
        _ => 'A note',
      };

  void _send() {
    _flush = null;
    for (final entry in _pending.entries) {
      final n = entry.value;
      _platform.notify(
        id: _savesId,
        channel: TibbChannel.arrivals,
        title: n == 1 ? 'Saved from ${entry.key}' : '$n items saved from ${entry.key}',
        body: n == 1 ? '${_lastKind[entry.key]} is on this phone now.' : 'They’re on this phone now.',
      );
    }
    _pending.clear();
    _lastKind.clear();
  }

  void dispose() {
    _flush?.cancel();
    _sub.cancel();
  }
}
