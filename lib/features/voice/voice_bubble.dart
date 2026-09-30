// Voice memo playback inside a bubble (design §9.3 "Voice"). The waveform is
// derived from the content hash, so each memo has a stable, distinct shape
// without decoding audio.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/app_scope.dart';
import '../../core/models.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';

class VoiceBubbleContent extends StatefulWidget {
  const VoiceBubbleContent({super.key, required this.item, required this.fg, required this.meta, required this.isSelf});
  final Item item;
  final Color fg;
  final Color meta;
  final bool isSelf;

  @override
  State<VoiceBubbleContent> createState() => _VoiceBubbleContentState();
}

class _VoiceBubbleContentState extends State<VoiceBubbleContent> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _pos;
  StreamSubscription<PlayerState>? _stateSub;
  Duration _position = Duration.zero;
  bool _playing = false;

  Duration get _total => Duration(milliseconds: widget.item.durationMs ?? 0);

  Future<void> _toggle() async {
    final repo = AppScope.of(context).repo;
    var player = _player;
    if (player == null) {
      final created = AudioPlayer();
      _player = created;
      player = created;
      try {
        await created.setFilePath(repo.blobs.pathFor(widget.item.blobHash!, widget.item.mime));
      } catch (_) {
        return;
      }
      _pos = created.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = created.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          created.seek(Duration.zero);
          created.pause();
        }
        setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
      });
    }
    if (_playing) {
      await player.pause();
    } else {
      // Not awaited: just_audio's play() completes only when playback stops.
      player.play();
    }
  }

  @override
  void dispose() {
    _pos?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  List<double> _bars() {
    final hash = widget.item.blobHash ?? widget.item.id;
    return [
      for (var i = 0; i < 24; i++)
        0.25 + (int.tryParse(hash[(i * 2) % hash.length], radix: 16) ?? 8) / 15 * 0.75,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = _total.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / _total.inMilliseconds;
    final bars = _bars();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        button: true,
        label: _playing ? 'Pause voice memo' : 'Play voice memo',
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isSelf ? c.textPrimary : c.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(_playing ? TibbIcons.pause : TibbIcons.play,
                size: 18, color: widget.isSelf ? c.background : c.textPrimary),
          ),
        ),
      ),
      const SizedBox(width: Space.s200),
      ExcludeSemantics(
        child: SizedBox(
          height: 24,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < bars.length; i++)
              Container(
                width: 3,
                height: 24 * bars[i],
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: (i / bars.length) <= progress && progress > 0
                      ? widget.fg
                      : widget.meta.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(width: Space.s200),
      Text(formatDuration(_playing || _position > Duration.zero ? _position : _total),
          style: context.type.monoSm.copyWith(color: widget.meta)),
    ]);
  }
}
