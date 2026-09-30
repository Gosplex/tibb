// The composer (design §9.2). Send appears only when there's text; otherwise
// the mic. Hold the mic to record, slide left to cancel, release to save.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../app/app_scope.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/tibb_button.dart';
import '../paywall/paywall_sheet.dart';
import 'capture.dart';

class Composer extends StatefulWidget {
  const Composer({super.key, required this.boxId, required this.onSaved});

  final String boxId;

  /// Called after a text save so the thread can run first-save moments.
  final VoidCallback onSaved;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _recorder = AudioRecorder();

  bool _recording = false;
  bool _cancelArmed = false;
  DateTime? _recordStart;
  Timer? _clock;
  Duration _elapsed = Duration.zero;
  double _level = 0;
  StreamSubscription<Amplitude>? _amp;

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _amp?.cancel();
    _recorder.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    AppScope.of(context).repo.addText(widget.boxId, text);
    _controller.clear();
    HapticFeedback.lightImpact();
    widget.onSaved();
  }

  Future<void> _startRecording() async {
    final pro = AppScope.of(context).pro;
    if (!pro.isPro) {
      await ensurePro(context, PaywallReason.voice);
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) showToast(context, 'Allow microphone access in Settings to record voice memos.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'rec-${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000), path: path);
    HapticFeedback.mediumImpact();
    _recordStart = DateTime.now();
    _amp = _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
      // dBFS roughly -60…0 → 0…1
      if (mounted) setState(() => _level = ((a.current + 60) / 60).clamp(0.0, 1.0).toDouble());
    });
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_recordStart!));
    });
    if (mounted) setState(() {
      _recording = true;
      _cancelArmed = false;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _stopRecording({required bool save}) async {
    if (!_recording) return;
    _clock?.cancel();
    await _amp?.cancel();
    _amp = null;
    final duration = DateTime.now().difference(_recordStart ?? DateTime.now());
    setState(() => _recording = false);
    if (!save || duration < const Duration(milliseconds: 700)) {
      await _recorder.cancel();
      if (mounted && save) showToast(context, 'Hold to record a voice memo.');
      return;
    }
    final path = await _recorder.stop();
    if (path == null || !mounted) return;
    await saveVoiceMemo(context, widget.boxId, File(path), duration);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(Space.s200, Space.s200, Space.s200, Space.s200),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          TibbIconButton(
            icon: TibbIcons.plus,
            label: 'Add photos, files or clipboard',
            onPressed: _recording ? null : () => showAttachSheet(context, widget.boxId),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion(Motion.fast),
              child: _recording ? _recordingStrip(context) : _field(context),
            ),
          ),
          const SizedBox(width: Space.s100),
          SizedBox(
            width: Sizes.touchTarget,
            height: Sizes.touchTarget,
            child: AnimatedSwitcher(
              duration: context.motion(Motion.fast),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: _hasText && !_recording
                  ? _SendButton(key: const ValueKey('send'), onTap: _send)
                  : _MicButton(
                      key: const ValueKey('mic'),
                      recording: _recording,
                      level: _level,
                      onStart: _startRecording,
                      onMove: (dx) {
                        final armed = dx < -80;
                        if (armed != _cancelArmed) {
                          HapticFeedback.selectionClick();
                          setState(() => _cancelArmed = armed);
                        }
                      },
                      onEnd: () => _stopRecording(save: !_cancelArmed),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      key: const ValueKey('field'),
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 144),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        minLines: 1,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        style: context.type.bodyLg,
        decoration: InputDecoration(
          hintText: 'Save something…',
          filled: true,
          fillColor: c.surfaceSunken,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.s400, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg), borderSide: BorderSide.none),
          enabledBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg), borderSide: BorderSide.none),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _recordingStrip(BuildContext context) {
    final c = context.colors;
    return Container(
      key: const ValueKey('rec'),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: Space.s400),
      decoration: BoxDecoration(
        color: _cancelArmed ? c.errorBg : c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c.errorFg, shape: BoxShape.circle)),
        const SizedBox(width: Space.s200),
        Semantics(
          liveRegion: true,
          label: 'Recording, ${formatDuration(_elapsed)}',
          child: Text(formatDuration(_elapsed), style: context.type.monoMd),
        ),
        const Spacer(),
        Text(_cancelArmed ? 'Release to cancel' : '‹ Slide to cancel',
            style: context.type.bodySm.copyWith(color: _cancelArmed ? c.errorFg : c.textTertiary)),
      ]),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Save',
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: Sizes.sendButton,
            height: Sizes.sendButton,
            decoration: BoxDecoration(color: c.actionPrimary, shape: BoxShape.circle),
            child: Icon(TibbIcons.send, size: 20, color: c.textOnAccent),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    super.key,
    required this.recording,
    required this.level,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
  });

  final bool recording;
  final double level;
  final VoidCallback onStart;
  final ValueChanged<double> onMove;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Hold to record a voice memo',
      child: GestureDetector(
        onTap: () => showToast(context, 'Hold to record a voice memo.'),
        onLongPressStart: (_) => onStart(),
        onLongPressMoveUpdate: (d) => onMove(d.offsetFromOrigin.dx),
        onLongPressEnd: (_) => onEnd(),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: recording ? 44 + 12 * level : Sizes.sendButton,
            height: recording ? 44 + 12 * level : Sizes.sendButton,
            decoration: BoxDecoration(
              color: recording ? c.errorFg : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(recording ? TibbIcons.micFill : TibbIcons.mic,
                size: 24, color: recording ? Colors.white : c.textPrimary),
          ),
        ),
      ),
    );
  }
}
