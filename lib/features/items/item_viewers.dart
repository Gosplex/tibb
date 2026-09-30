// Viewers for media items (design S4). Images and video open in-app on black
// (media needs neutral surroundings in both themes); other files go to the
// system share sheet ("Open with…", Save to Files, Quick Look on iPhone).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_scope.dart';
import '../../core/models.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';

void openImageViewer(BuildContext context, Item item, String path) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: context.motion(Motion.normal),
    pageBuilder: (_, __, ___) => _ImageViewer(item: item, path: path),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
  ));
}

void openVideoViewer(BuildContext context, Item item, String path) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _VideoViewer(item: item, path: path),
  ));
}

/// Copies the blob to a temp file with its original name (blobs are stored by
/// hash) and opens the share sheet.
Future<void> openFileExternally(BuildContext context, Item item) async {
  final repo = AppScope.of(context).repo;
  final hash = item.blobHash;
  if (hash == null) return;
  final src = repo.blobs.fileFor(hash, item.mime);
  if (!await src.exists()) {
    if (context.mounted) showToast(context, "This file isn't on this phone anymore.");
    return;
  }
  final tmpDir = await getTemporaryDirectory();
  final name = item.fileName ?? 'tibb-file${p.extension(src.path)}';
  final out = File(p.join(tmpDir.path, 'share-${item.id.substring(0, 8)}', name));
  await out.parent.create(recursive: true);
  if (!await out.exists()) await src.copy(out.path);
  if (!context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await Share.shareXFiles(
    [XFile(out.path, mimeType: item.mime, name: name)],
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}

class _ViewerBar extends StatelessWidget {
  const _ViewerBar({required this.item, required this.onShare});
  final Item item;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final origin = item.originDeviceName ?? 'This phone';
    return SafeArea(
      bottom: false,
      child: Row(children: [
        IconButton(
          tooltip: 'Close',
          icon: const Icon(TibbIcons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text('$origin · ${formatDay(item.createdAt)} ${formatTime(item.createdAt)}',
              style: t.caption.copyWith(color: Colors.white70), textAlign: TextAlign.center),
        ),
        IconButton(
          tooltip: 'Share',
          icon: const Icon(TibbIcons.exportIcon, color: Colors.white),
          onPressed: onShare,
        ),
      ]),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.item, required this.path});
  final Item item;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            // Swipe down to dismiss (design S4).
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
            },
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Hero(
                  tag: 'img-${item.id}',
                  child: Image.file(File(path), fit: BoxFit.contain, semanticLabel: item.fileName ?? 'Photo'),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ViewerBar(item: item, onShare: () => openFileExternally(context, item)),
        ),
      ]),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.item, required this.path});
  final Item item;
  final String path;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final VideoPlayerController _controller = VideoPlayerController.file(File(widget.path));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Center(
          child: _failed
              ? Text("This video can't play here. Use Share to open it in another app.",
                  style: context.type.bodyMd.copyWith(color: Colors.white70), textAlign: TextAlign.center)
              : ready
                  ? GestureDetector(
                      onTap: () => _controller.value.isPlaying ? _controller.pause() : _controller.play(),
                      child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ViewerBar(item: widget.item, onShare: () => openFileExternally(context, widget.item)),
        ),
        if (ready)
          Positioned(
            left: Space.s400,
            right: Space.s400,
            bottom: Space.s400,
            child: SafeArea(
              top: false,
              child: Row(children: [
                IconButton(
                  tooltip: _controller.value.isPlaying ? 'Pause' : 'Play',
                  icon: Icon(_controller.value.isPlaying ? TibbIcons.pause : TibbIcons.play, color: Colors.white),
                  onPressed: () => _controller.value.isPlaying ? _controller.pause() : _controller.play(),
                ),
                Expanded(child: VideoProgressIndicator(_controller, allowScrubbing: true)),
                const SizedBox(width: Space.s300),
                Text(formatDuration(_controller.value.duration),
                    style: context.type.monoSm.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
      ]),
    );
  }
}
