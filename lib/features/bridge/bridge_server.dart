// Tibb Bridge (brief §7.9) — the phone serves a small web page and a JSON API
// to one paired browser on the same Wi-Fi. Built on dart:io's HttpServer (no
// framework) so uploads/downloads stream straight to and from disk.
//
// Security model (stated honestly in-app): LAN only, plain HTTP, single-use
// 6-digit pairing code (5 min, 5 attempts), one session at a time, 32-byte
// bearer token held in the browser's memory, 30 min idle expiry.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models.dart';
import '../../core/platform/tibb_platform.dart';
import '../../core/repository/library_repository.dart';
import '../../core/util/format.dart';
import '../../core/util/ids.dart';
import '../locked/lock_service.dart';
import '../whatsapp_import/whatsapp_importer.dart';

enum BridgeStatus { idle, starting, waiting, connected, error }

enum BridgeError { noWifi, bindFailed }

class BridgeSession {
  BridgeSession({required this.token, required this.deviceId, required this.deviceName})
      : connectedAt = DateTime.now(),
        lastSeen = DateTime.now();
  final String token;
  final String deviceId;
  String deviceName;
  final DateTime connectedAt;
  DateTime lastSeen;
  int received = 0; // items the phone received from the PC
}

class BridgeServer extends ChangeNotifier {
  BridgeServer(this._repo, this._locks) {
    _locks.addListener(notifyListeners);
  }

  final LibraryRepository _repo;
  final LockService _locks;

  static const _codeLifetime = Duration(minutes: 5);
  static const _sessionIdle = Duration(minutes: 30);
  static const _maxAttempts = 5;

  HttpServer? _server;
  BridgeStatus status = BridgeStatus.idle;
  BridgeError? error;
  String? host;
  int? port;
  String? code;
  DateTime? codeExpiresAt;
  int _attempts = 0;
  BridgeSession? session;
  Timer? _ticker;

  /// Pro state, wired from main(). Bridge itself is Pro, but a plan can lapse
  /// mid-session; creation gates follow the live value.
  bool Function() isPro = () => true;

  // WhatsApp import started from the computer (one at a time).
  WaPrepared? _wa;
  String _waState = 'idle'; // idle | ready | running | done | error
  int _waDone = 0;
  int _waTotal = 0;
  bool _waCancel = false;
  WaImportSummary? _waSummary;
  String? _waError;

  /// When the server started listening (drives the sheet's "Not connecting?" hint).
  DateTime? startedAt;

  String? get address => host == null ? null : '$host:$port';
  bool get isRunning => _server != null;
  bool get isConnected => session != null;

  Duration get codeTimeLeft {
    final exp = codeExpiresAt;
    if (exp == null) return Duration.zero;
    final d = exp.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle

  Future<void> start() async {
    if (isRunning) return;
    status = BridgeStatus.starting;
    error = null;
    notifyListeners();

    final ip = await localIPv4();
    if (ip == null) {
      status = BridgeStatus.error;
      error = BridgeError.noWifi;
      notifyListeners();
      return;
    }
    try {
      _server = await _bind(ip);
    } catch (e) {
      debugPrint('Tibb Bridge: bind failed: $e');
      status = BridgeStatus.error;
      error = BridgeError.bindFailed;
      notifyListeners();
      return;
    }
    host = ip;
    port = _server!.port;
    startedAt = DateTime.now();
    _server!.listen(_handle, onError: (Object e) => debugPrint('Tibb Bridge: $e'));
    _newCode();
    status = BridgeStatus.waiting;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
    if (Platform.isIOS) {
      // iOS suspends backgrounded apps, which would silently drop the Bridge.
      // Keeping the screen awake while it runs is the honest fix (brief §7.9).
      unawaited(WakelockPlus.enable().catchError((Object _) {}));
    } else {
      // Android: a foreground service keeps the session alive while minimized.
      _syncService();
    }
    unawaited(_nudgeLocalNetworkPermission(ip));
  }

  Future<HttpServer> _bind(String ip) async {
    final address = InternetAddress(ip);
    try {
      return await HttpServer.bind(address, 8080);
    } on SocketException {
      return HttpServer.bind(address, 0); // 8080 taken: any free port
    }
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    final s = _server;
    _server = null;
    session = null;
    code = null;
    host = null;
    port = null;
    status = BridgeStatus.idle;
    _locks.shareLockedWithBridge = false;
    notifyListeners();
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    unawaited(TibbPlatform.instance.stopBridgeService());
    await s?.close(force: true);
  }

  void _newCode() {
    code = randomDigits(6);
    codeExpiresAt = DateTime.now().add(_codeLifetime);
    _attempts = 0;
  }

  void _tick() {
    if (session == null) {
      if (codeTimeLeft == Duration.zero) _newCode();
      notifyListeners(); // drives the countdown ring
    } else if (DateTime.now().difference(session!.lastSeen) > _sessionIdle) {
      _endSession();
    }
  }

  void _endSession() {
    session = null;
    _locks.shareLockedWithBridge = false;
    _newCode();
    status = BridgeStatus.waiting;
    _syncService();
    notifyListeners();
  }

  /// Keeps the Android persistent notification in step with the session.
  void _syncService() {
    if (!isRunning) return;
    final s = session;
    unawaited(TibbPlatform.instance.startBridgeService(
      title: s == null ? 'Bridge is on' : '${s.deviceName} is connected',
      body: s == null ? 'Type ${address ?? 'the address'} on your computer.' : 'Tap Stop to disconnect.',
    ));
  }

  void disconnectBrowser() => _endSession();

  void setShareLocked(bool value) {
    _locks.shareLockedWithBridge = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Network helpers

  /// Picks the phone's Wi-Fi (en0 / wlan0) or hotspot IPv4 address.
  static Future<String?> localIPv4() async {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false, includeLinkLocal: false);
    String? pick(bool Function(NetworkInterface) test) {
      for (final i in interfaces.where(test)) {
        for (final a in i.addresses) {
          if (_isPrivate(a.address)) return a.address;
        }
      }
      return null;
    }

    return pick((i) => i.name == 'en0' || i.name == 'wlan0') ??
        // iPhone hotspot = bridge100; Android hotspot = ap0 / swlan0 / wlan1.
        pick((i) => i.name.startsWith('bridge') || i.name.startsWith('ap') || i.name.startsWith('swlan') || i.name == 'wlan1') ??
        pick((i) => !i.name.startsWith('pdp_ip') && !i.name.startsWith('rmnet') && !i.name.startsWith('utun'));
  }

  static bool _isPrivate(String ip) {
    if (ip.startsWith('10.') || ip.startsWith('192.168.')) return true;
    if (ip.startsWith('172.')) {
      final second = int.tryParse(ip.split('.')[1]) ?? 0;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  /// iOS only shows the Local Network permission prompt when the app sends
  /// traffic on the LAN. A single datagram to the discard port triggers it
  /// early, while the user is looking at the Bridge screen.
  Future<void> _nudgeLocalNetworkPermission(String ip) async {
    if (!Platform.isIOS) return;
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final parts = ip.split('.');
      final broadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
      socket.send(utf8.encode('tibb'), InternetAddress(broadcast), 9);
      socket.close();
    } catch (_) {/* harmless: the prompt will still appear on first connection */}
  }

  // ---------------------------------------------------------------------------
  // HTTP handling

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Cache-Control', 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer');
    try {
      final path = req.uri.path;
      if (!path.startsWith('/api/')) {
        await _serveStatic(req, path);
        return;
      }
      if (path == '/api/pair' && req.method == 'POST') {
        await _pair(req);
        return;
      }
      final s = _authorize(req);
      if (s == null) {
        await _json(res, {'error': 'unauthorized'}, status: HttpStatus.unauthorized);
        return;
      }
      s.lastSeen = DateTime.now();
      switch ((req.method, path)) {
        case ('GET', '/api/state'):
          await _json(res, _state());
        case ('GET', '/api/items'):
          await _items(req);
        case ('GET', '/api/search'):
          await _search(req);
        case ('POST', '/api/items'):
          await _createText(req, s);
        case ('POST', '/api/upload'):
          await _upload(req, s);
        case ('POST', '/api/clipboard'):
          await _clipboard(req, s);
        case ('POST', '/api/device'):
          await _renameDevice(req, s);
        case ('GET', '/api/events'):
          await _events(req);
        case ('POST', '/api/items/update'):
          await _updateItem(req, s);
        case ('POST', '/api/import/whatsapp'):
          await _waUpload(req);
        case ('POST', '/api/import/whatsapp/order'):
          await _waOrder(req);
        case ('POST', '/api/import/whatsapp/commit'):
          await _waCommit(req);
        case ('GET', '/api/import/whatsapp/status'):
          await _json(res, _waStatus());
        case ('DELETE', '/api/import/whatsapp'):
          await _waDiscard();
          await _json(res, {'ok': true});
        case ('DELETE', '/api/session'):
          _endSession();
          await _json(res, {'ok': true});
        default:
          if (req.method == 'GET' && path.startsWith('/api/blob/')) {
            await _blob(req, path.substring('/api/blob/'.length));
          } else {
            await _json(res, {'error': 'not_found'}, status: HttpStatus.notFound);
          }
      }
    } catch (e, st) {
      debugPrint('Tibb Bridge: request failed: $e\n$st');
      try {
        await _json(res, {'error': 'server_error'}, status: HttpStatus.internalServerError);
      } catch (_) {/* response already started */}
    }
  }

  BridgeSession? _authorize(HttpRequest req) {
    final s = session;
    if (s == null) return null;
    final header = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : req.uri.queryParameters['t'];
    return token == s.token ? s : null;
  }

  static const _staticFiles = <String, (String, String)>{
    '/': ('assets/bridge/index.html', 'text/html; charset=utf-8'),
    '/index.html': ('assets/bridge/index.html', 'text/html; charset=utf-8'),
    '/app.css': ('assets/bridge/app.css', 'text/css; charset=utf-8'),
    '/app.js': ('assets/bridge/app.js', 'text/javascript; charset=utf-8'),
    '/mark.png': ('assets/brand/tibb_mark.png', 'image/png'),
    '/fonts/Figtree.ttf': ('assets/fonts/Figtree-Variable.ttf', 'font/ttf'),
    '/fonts/Fraunces.ttf': ('assets/fonts/Fraunces-Variable.ttf', 'font/ttf'),
    '/fonts/JetBrainsMono.ttf': ('assets/fonts/JetBrainsMono-Variable.ttf', 'font/ttf'),
  };

  Future<void> _serveStatic(HttpRequest req, String path) async {
    final res = req.response;
    final entry = _staticFiles[path];
    if (entry == null || req.method != 'GET') {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final data = await rootBundle.load(entry.$1);
    res.headers.set(HttpHeaders.contentTypeHeader, entry.$2);
    if (entry.$2.startsWith('text/html')) {
      // No external requests of any kind (brief §7.9): everything is same-origin.
      res.headers.set('Content-Security-Policy',
          "default-src 'self'; img-src 'self' blob: data:; media-src 'self'; font-src 'self'; "
          "style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'");
    }
    res.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    await res.close();
  }

  Future<void> _pair(HttpRequest req) async {
    final body = await _readJson(req);
    if (session != null) {
      await _json(req.response, {'error': 'busy'}, status: HttpStatus.conflict);
      return;
    }
    final submitted = (body['code'] as String? ?? '').trim();
    if (code == null || codeTimeLeft == Duration.zero) {
      _newCode();
      notifyListeners();
      await _json(req.response, {'error': 'expired'}, status: HttpStatus.forbidden);
      return;
    }
    if (submitted != code) {
      _attempts++;
      if (_attempts >= _maxAttempts) _newCode();
      notifyListeners();
      await _json(req.response, {'error': 'wrong_code'}, status: HttpStatus.forbidden);
      return;
    }
    final deviceId = _validId(body['deviceId'] as String?) ?? newId();
    // Keep a name the owner chose earlier; otherwise derive "Chrome on Windows".
    final known = _repo.deviceNameFor(deviceId);
    final name = known == 'Another device'
        ? deviceNameFromUserAgent(req.headers.value(HttpHeaders.userAgentHeader))
        : known;
    _repo.registerDevice(deviceId, name);
    session = BridgeSession(token: randomHex(32), deviceId: deviceId, deviceName: _repo.deviceNameFor(deviceId));
    code = null; // single use
    status = BridgeStatus.connected;
    HapticFeedback.mediumImpact();
    _syncService();
    notifyListeners();
    await _json(req.response, {
      'token': session!.token,
      'deviceId': deviceId,
      'deviceName': session!.deviceName,
      'phoneName': _repo.deviceName,
    });
  }

  String? _validId(String? id) =>
      id != null && RegExp(r'^[0-9a-f-]{36}$').hasMatch(id) ? id : null;

  bool _visible(Box b) => !b.locked || _locks.shareLockedWithBridge;

  Map<String, Object?> _state() {
    final clip = _repo.latestClipboard();
    return {
      'phoneName': _repo.deviceName,
      'seq': _repo.log.lastSeq,
      'defaultBoxId': _repo.defaultBoxId,
      'boxes': [
        for (final b in _repo.boxes())
          {
            ...b.toJson(),
            'hidden': !_visible(b),
            'preview': _visible(b) ? b.lastPreview : null,
          }
      ],
      'clipboard': clip == null ? null : _itemJson(clip),
      'thisDevice': session?.deviceId,
    };
  }

  Map<String, Object?> _itemJson(Item i) => {
        ...i.toJson(),
        'fromPhone': _repo.isThisDevice(i.originDeviceId),
        'originName': _repo.isThisDevice(i.originDeviceId) ? _repo.deviceName : i.originDeviceName,
      };

  Future<void> _items(HttpRequest req) async {
    final q = req.uri.queryParameters;
    final b = _repo.box(q['box'] ?? '');
    if (b == null) {
      await _json(req.response, {'error': 'not_found'}, status: HttpStatus.notFound);
      return;
    }
    if (!_visible(b)) {
      await _json(req.response, {'error': 'locked'}, status: HttpStatus.forbidden);
      return;
    }
    final items = _repo.items(b.id, archived: q['archived'] == '1');
    await _json(req.response, {'items': [for (final i in items) _itemJson(i)]});
  }

  Future<void> _search(HttpRequest req) async {
    final q = req.uri.queryParameters['q'] ?? '';
    final unlocked = _locks.shareLockedWithBridge
        ? {for (final b in _repo.boxes()) b.id}
        : _locks.unlockedBoxIds;
    final results = _repo.search(q, unlockedBoxIds: unlocked);
    await _json(req.response, {
      'results': [
        for (final r in results) {..._itemJson(r.item), 'boxName': r.box.name, 'boxEmoji': r.box.emoji}
      ]
    });
  }

  Future<Box?> _targetBox(String? id, HttpResponse res) async {
    final b = _repo.box(id ?? _repo.defaultBoxId);
    if (b == null || !_visible(b)) {
      await _json(res, {'error': 'box_unavailable'}, status: HttpStatus.forbidden);
      return null;
    }
    return b;
  }

  Future<void> _createText(HttpRequest req, BridgeSession s) async {
    final body = await _readJson(req);
    final text = (body['text'] as String? ?? '').trim();
    if (text.isEmpty) {
      await _json(req.response, {'error': 'empty'}, status: HttpStatus.badRequest);
      return;
    }
    final b = await _targetBox(body['boxId'] as String?, req.response);
    if (b == null) return;
    final item = _repo.addText(b.id, text, authorDeviceId: s.deviceId);
    s.received++;
    await _json(req.response, {'item': _itemJson(item)});
  }

  Future<void> _clipboard(HttpRequest req, BridgeSession s) async {
    final body = await _readJson(req);
    final text = (body['text'] as String? ?? '').trim();
    if (text.isEmpty) {
      await _json(req.response, {'error': 'empty'}, status: HttpStatus.badRequest);
      return;
    }
    final item = _repo.addClipboard(text, authorDeviceId: s.deviceId);
    s.received++;
    await _json(req.response, {'item': _itemJson(item)});
  }

  Future<void> _upload(HttpRequest req, BridgeSession s) async {
    final q = req.uri.queryParameters;
    final b = await _targetBox(q['box'], req.response);
    if (b == null) return;
    final name = _safeFileName(q['name'] ?? 'file');
    var mime = req.headers.contentType?.mimeType ?? '';
    if (mime.isEmpty || mime == 'application/octet-stream') mime = mimeFromName(name);
    final blob = await _repo.blobs.ingestStream(req, mime: mime);
    final item = _repo.addBlob(b.id, blob, fileName: name, authorDeviceId: s.deviceId);
    s.received++;
    await _json(req.response, {'item': _itemJson(item)});
  }

  /// Archive or pin from the computer. Same repository path as the phone.
  Future<void> _updateItem(HttpRequest req, BridgeSession s) async {
    final body = await _readJson(req);
    final item = _repo.item(body['id'] as String? ?? '');
    final b = item == null ? null : _repo.box(item.boxId);
    if (item == null || b == null || !_visible(b) || (item.type == ItemType.clipboard && body['archived'] != null)) {
      await _json(req.response, {'error': 'not_found'}, status: HttpStatus.notFound);
      return;
    }
    _repo.updateItem(
      item.id,
      archived: body['archived'] as bool?,
      pinned: body['pinned'] as bool?,
      authorDeviceId: s.deviceId,
    );
    await _json(req.response, {'item': _itemJson(_repo.item(item.id)!)});
  }

  // ---------------------------------------------------------------------------
  // WhatsApp import from the computer (brief §7.12). The export is streamed to
  // the phone's temp folder, parsed on the phone, previewed in the browser,
  // and imported through the same WhatsAppImporter the phone screen uses.

  Map<String, Object?> _waPreview() {
    final w = _wa!;
    final r = w.result;
    return {
      'state': _waState,
      'fileName': w.sourceName,
      'messages': r.messages.length,
      'first': r.messages.first.time.millisecondsSinceEpoch,
      'last': r.messages.last.time.millisecondsSinceEpoch,
      'senders': r.senders,
      'dayFirst': r.dayFirst,
      'certain': r.dateOrderCertain,
      'textCount': r.messages.where((m) => m.attachment == null).length,
      'mediaCount': w.mediaAvailable,
      'samples': [
        for (final m in w.samples()) {'time': m.time.millisecondsSinceEpoch, 'text': m.text}
      ],
      'isPro': isPro(),
    };
  }

  Map<String, Object?> _waStatus() => {
        'state': _waState,
        'done': _waDone,
        'total': _waTotal,
        if (_waSummary != null) 'summary': _waSummary!.toJson(),
        if (_waError != null) 'error': _waError,
      };

  Future<void> _waDiscard() async {
    _waCancel = true;
    final w = _wa;
    _wa = null;
    if (_waState != 'running') _waState = 'idle';
    await w?.dispose();
  }

  Future<void> _waUpload(HttpRequest req) async {
    if (_waState == 'running') {
      await _json(req.response, {'error': 'busy'}, status: HttpStatus.conflict);
      return;
    }
    await _waDiscard();
    final tmp = await getTemporaryDirectory();
    final name = _safeFileName(req.uri.queryParameters['name'] ?? 'export.zip');
    final file = File(p.join(tmp.path, 'wa-upload-${DateTime.now().microsecondsSinceEpoch}-$name'));
    try {
      final sink = file.openWrite();
      await sink.addStream(req);
      await sink.close();
      _wa = await WhatsAppImporter.prepare(file, parent: tmp, displayName: name);
      _waState = 'ready';
      _waSummary = null;
      _waError = null;
      await _json(req.response, _waPreview());
    } on WaImportException catch (e) {
      _waState = 'idle';
      await _json(req.response, {'error': e.kind.name, 'message': e.message}, status: HttpStatus.unprocessableEntity);
    } finally {
      if (await file.exists()) await file.delete().catchError((Object _) => file);
    }
  }

  Future<void> _waOrder(HttpRequest req) async {
    final body = await _readJson(req);
    if (_wa == null || _waState != 'ready') {
      await _json(req.response, {'error': 'no_import'}, status: HttpStatus.notFound);
      return;
    }
    await _wa!.setDayFirst(body['dayFirst'] != false);
    await _json(req.response, _waPreview());
  }

  Future<void> _waCommit(HttpRequest req) async {
    final body = await _readJson(req);
    final w = _wa;
    if (w == null || _waState != 'ready') {
      await _json(req.response, {'error': 'no_import'}, status: HttpStatus.notFound);
      return;
    }
    final senders = <String>{
      for (final x in (body['senders'] as List?) ?? w.result.senders) x.toString(),
    };
    final includeMedia = body['includeMedia'] != false;
    _waState = 'running';
    _waDone = 0;
    _waTotal = 0;
    _waCancel = false;
    _waError = null;
    await _json(req.response, {'ok': true});
    // Runs after the response; the page polls /status for progress.
    unawaited(() async {
      try {
        final summary = await WhatsAppImporter(_repo).run(
          w,
          senders: senders,
          includeMedia: includeMedia,
          isPro: isPro(),
          isCancelled: () => _waCancel,
          onProgress: (d, t) {
            _waDone = d;
            _waTotal = t;
          },
        );
        _waSummary = summary;
        _waState = 'done';
        WhatsAppImporter.notifyIfBackground(summary.created);
      } on WaImportException catch (e) {
        _waError = e.message;
        _waState = 'error';
      } catch (_) {
        _waError = const WaImportException(WaImportError.failed).message;
        _waState = 'error';
      } finally {
        if (identical(_wa, w)) _wa = null;
        await w.dispose();
      }
    }());
  }

  Future<void> _renameDevice(HttpRequest req, BridgeSession s) async {
    final body = await _readJson(req);
    final name = (body['name'] as String? ?? '').trim();
    if (name.isEmpty || name.length > 40) {
      await _json(req.response, {'error': 'invalid'}, status: HttpStatus.badRequest);
      return;
    }
    _repo.registerDevice(s.deviceId, name);
    s.deviceName = name;
    _syncService();
    notifyListeners();
    await _json(req.response, {'ok': true});
  }

  /// Long-poll: answers as soon as the change log moves past `since`, or after 25 s.
  Future<void> _events(HttpRequest req) async {
    final since = int.tryParse(req.uri.queryParameters['since'] ?? '') ?? 0;
    if (_repo.log.lastSeq <= since) {
      final changed = Completer<void>();
      final sub = _repo.changes.listen((_) {
        if (!changed.isCompleted) changed.complete();
      });
      await changed.future.timeout(const Duration(seconds: 25), onTimeout: () {});
      await sub.cancel();
    }
    await _json(req.response, {'seq': _repo.log.lastSeq});
  }

  Future<void> _blob(HttpRequest req, String hash) async {
    final res = req.response;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) || !_repo.isBlobReferenced(hash)) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final mime = _repo.blobMime(hash) ?? 'application/octet-stream';
    final file = _repo.blobs.fileFor(hash, mime);
    if (!await file.exists()) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final length = await file.length();
    final q = req.uri.queryParameters;
    // Only media and PDFs render inline; everything else downloads, so an
    // uploaded HTML/SVG file can never run script on this origin.
    final inlineSafe = (mime.startsWith('image/') && mime != 'image/svg+xml') ||
        mime.startsWith('video/') ||
        mime.startsWith('audio/') ||
        mime == 'application/pdf';
    res.headers.set(HttpHeaders.contentTypeHeader, inlineSafe ? mime : 'application/octet-stream');
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (q['dl'] == '1' || !inlineSafe) {
      final name = _safeFileName(q['name'] ?? 'tibb-file');
      res.headers.set('Content-Disposition',
          'attachment; filename="${name.replaceAll('"', '')}"; filename*=UTF-8\'\'${Uri.encodeComponent(name)}');
    }

    var start = 0;
    var end = length - 1;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
    if (m != null && length > 0) {
      final a = m.group(1)!, b = m.group(2)!;
      if (a.isEmpty && b.isNotEmpty) {
        final suffix = int.parse(b);
        start = suffix >= length ? 0 : length - suffix;
      } else {
        start = int.tryParse(a) ?? 0;
        if (b.isNotEmpty) {
          final requested = int.parse(b);
          end = requested < start ? start : (requested > length - 1 ? length - 1 : requested);
        }
      }
      if (start >= length) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length');
    }
    res.contentLength = length == 0 ? 0 : end - start + 1;
    if (length > 0) await res.addStream(file.openRead(start, end + 1));
    await res.close();
  }

  // ---------------------------------------------------------------------------

  static String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/\x00-\x1f]'), '_').trim();
    if (cleaned.isEmpty) return 'file';
    return cleaned.length > 120 ? cleaned.substring(cleaned.length - 120) : cleaned;
  }

  static Future<Map<String, Object?>> _readJson(HttpRequest req) async {
    // Small JSON bodies only; uploads use the streaming endpoint.
    final bytes = await req.fold<List<int>>(<int>[], (acc, chunk) {
      if (acc.length + chunk.length > 256 * 1024) throw const FormatException('body too large');
      return acc..addAll(chunk);
    });
    if (bytes.isEmpty) return {};
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map ? Map<String, Object?>.from(decoded) : {};
  }

  static Future<void> _json(HttpResponse res, Object body, {int status = HttpStatus.ok}) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    await res.close();
  }

  @override
  void dispose() {
    _locks.removeListener(notifyListeners);
    _ticker?.cancel();
    _server?.close(force: true);
    super.dispose();
  }
}
