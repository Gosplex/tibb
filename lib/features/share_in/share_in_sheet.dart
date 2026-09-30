// Share into Tibb (design S13 / journey J2). Another app hands Tibb text, a
// link or files; this half-height sheet shows what arrived, which box it goes
// to (optional — the default is always fine), and one Save button.
// On success: the lid closes, "Tucked into Personal.", and after 900 ms the
// user is back in the app they came from.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/blobs/blob_store.dart';
import '../../core/models.dart';
import '../../core/platform/tibb_platform.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/illustrations.dart';
import '../../design/widgets/tibb_button.dart';
import '../paywall/paywall_sheet.dart';

/// Shows the share sheet. Returns true when something was saved.
Future<bool> showShareInSheet(BuildContext context, SharePayload payload) async {
  final saved = await showTibbSheet<bool>(context, builder: (_) => ShareInSheet(payload: payload));
  return saved ?? false;
}

enum _Phase { ready, saving, done }

class ShareInSheet extends StatefulWidget {
  const ShareInSheet({super.key, required this.payload});
  final SharePayload payload;

  @override
  State<ShareInSheet> createState() => _ShareInSheetState();
}

class _ShareInSheetState extends State<ShareInSheet> {
  late String _boxId;
  String? _redirectNote;
  _Phase _phase = _Phase.ready;
  double? _progress;
  String? _error;
  bool _init = false;

  SharePayload get _p => widget.payload;
  String get _text => (_p.text ?? '').trim();
  int get _totalBytes => _p.files.fold(0, (a, f) => a + f.size);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final repo = AppScope.of(context).repo;
    final preferred = repo.box(repo.defaultBoxId);
    if (preferred != null && preferred.locked) {
      // Never prompt biometrics inside a share flow (brief §7.2).
      final open = repo.boxes().where((b) => !b.locked).firstOrNull;
      _boxId = open?.id ?? preferred.id;
      _redirectNote = 'Locked boxes can’t receive shares yet — saving to ${open?.name ?? preferred.name}.';
    } else {
      _boxId = preferred?.id ?? repo.defaultBoxId;
    }
  }

  @override
  void dispose() {
    // Anything not saved is removed from the share cache.
    if (_phase != _Phase.done) {
      for (final f in _p.files) {
        File(f.path).delete().ignore();
      }
    }
    super.dispose();
  }

  Future<void> _pickBox() async {
    final repo = AppScope.of(context).repo;
    final boxes = repo.boxes().where((b) => !b.locked).toList();
    if (boxes.length < 2) return;
    final chosen = await showTibbSheet<String>(context, builder: (ctx) {
      final c = ctx.colors;
      return SheetScaffold(
        title: 'Save to',
        child: Column(children: [
          for (final b in boxes)
            InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () => Navigator.of(ctx).pop(b.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.s200, vertical: Space.s200),
                decoration: BoxDecoration(
                  color: b.id == _boxId ? c.highlight : null,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(children: [
                  BoxTile(box: b),
                  const SizedBox(width: Space.s300),
                  Expanded(child: Text(b.name, style: ctx.type.titleXs)),
                  if (b.id == _boxId) Icon(TibbIcons.check, color: c.textPrimary),
                ]),
              ),
            ),
        ]),
      );
    });
    if (chosen != null && mounted) setState(() => _boxId = chosen);
  }

  Future<void> _save({bool textOnly = false}) async {
    final s = AppScope.of(context);
    final files = textOnly ? const <SharedFile>[] : _p.files;
    if (files.isNotEmpty && !await ensurePro(context, PaywallReason.media)) return;
    if (!mounted) return;
    setState(() {
      _phase = _Phase.saving;
      _error = null;
      _progress = _totalBytes > 20 * 1024 * 1024 ? 0 : null;
    });

    try {
      if (_text.isNotEmpty) s.repo.addText(_boxId, _text);
      var doneBytes = 0;
      for (final f in files) {
        final base = doneBytes;
        final blob = await s.repo.blobs.ingestStream(
          File(f.path).openRead(),
          mime: f.mime,
          onProgress: _progress == null || _totalBytes == 0
              ? null
              : (n) {
                  if (mounted) setState(() => _progress = (base + n) / _totalBytes);
                },
        );
        doneBytes += f.size;
        // Unsupported types are simply saved as files (brief §7.2).
        s.repo.addBlob(_boxId, blob, fileName: f.name, type: ItemType.forMime(f.mime));
        File(f.path).delete().ignore();
      }
    } on StorageFullException {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _phase = _Phase.ready;
          _error = 'Your phone is out of space. Free some up, then try again — nothing was lost.';
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _Phase.ready;
          _error = "Couldn't save that. Try again.";
        });
      }
      return;
    }

    if (!mounted) return;
    HapticFeedback.lightImpact();
    s.repo.incrementCounter('saves_count');
    setState(() => _phase = _Phase.done);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final box = s.repo.box(_boxId);
    return ListenableBuilder(
      listenable: s.pro,
      builder: (context, _) => SheetScaffold(
        title: _phase == _Phase.done ? null : 'Save to Tibb',
        child: AnimatedSwitcher(
          duration: context.motion(Motion.normal),
          child: _phase == _Phase.done ? _doneView(context, box?.name ?? 'your box') : _form(context, box),
        ),
      ),
    );
  }

  Widget _doneView(BuildContext context, String boxName) => Padding(
        key: const ValueKey('done'),
        padding: const EdgeInsets.symmetric(vertical: Space.s600),
        child: Column(children: [
          const LidClose(width: 120),
          const SizedBox(height: Space.s400),
          Semantics(liveRegion: true, child: Text('Tucked into $boxName.', style: context.type.titleMd)),
          const SizedBox(height: Space.s100),
          Text('Saved on this phone. Nothing left it.',
              style: context.type.bodySm.copyWith(color: context.colors.textSecondary)),
        ]),
      );

  Widget _form(BuildContext context, Box? box) {
    final c = context.colors;
    final t = context.type;
    final pro = AppScope.of(context).pro.isPro;
    final needsPro = _p.files.isNotEmpty && !pro;
    final saving = _phase == _Phase.saving;
    final boxCount = AppScope.of(context).repo.boxes().where((b) => !b.locked).length;

    return Column(key: const ValueKey('form'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Preview(payload: _p, text: _text),
      const SizedBox(height: Space.s400),
      if (box != null)
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: boxCount > 1,
            label: 'Saving to ${box.name}${boxCount > 1 ? '. Change box' : ''}',
            excludeSemantics: true,
            child: InkWell(
              onTap: saving || boxCount < 2 ? null : _pickBox,
              borderRadius: BorderRadius.circular(Radii.full),
              child: Container(
                padding: const EdgeInsets.fromLTRB(Space.s100, Space.s100, Space.s300, Space.s100),
                decoration: BoxDecoration(
                  color: c.surfaceSunken,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  BoxTile(box: box, size: 28),
                  const SizedBox(width: Space.s200),
                  Text(box.name, style: t.labelLg),
                  if (boxCount > 1) ...[
                    const SizedBox(width: Space.s100),
                    Icon(TibbIcons.caretDown, size: 16, color: c.textSecondary),
                  ],
                ]),
              ),
            ),
          ),
        ),
      if (_redirectNote != null) ...[
        const SizedBox(height: Space.s300),
        InfoCard(tone: InfoTone.private, title: _redirectNote!),
      ],
      if (_p.failed > 0) ...[
        const SizedBox(height: Space.s300),
        InfoCard(
          tone: InfoTone.warning,
          title: '${_p.failed} item${_p.failed == 1 ? '' : 's'} couldn’t be read',
          body: 'The other app didn’t hand them over. Try sharing them again.',
        ),
      ],
      if (needsPro) ...[
        const SizedBox(height: Space.s300),
        InfoCard(
          tone: InfoTone.info,
          icon: TibbIcons.pro,
          title: 'Photos and files are part of Pro',
          body: _text.isNotEmpty
              ? 'Save the text now, or get Pro to keep the files too.'
              : 'Get Pro to keep photos, videos, voice and files. Text and links are always free.',
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: Space.s300),
        InfoCard(tone: InfoTone.error, title: _error!),
      ],
      if (_progress != null && saving) ...[
        const SizedBox(height: Space.s400),
        TibbProgress(value: _progress, label: 'Saving ${formatBytes(_totalBytes)}'),
      ],
      const SizedBox(height: Space.s600),
      TibbButton(
        label: needsPro ? 'See Pro' : 'Save',
        icon: needsPro ? TibbIcons.pro : null,
        loading: saving,
        onPressed: saving ? null : () => _save(),
      ),
      if (needsPro && _text.isNotEmpty) ...[
        const SizedBox(height: Space.s200),
        TibbButton(
          label: 'Save text only',
          variant: TibbButtonVariant.ghost,
          size: TibbButtonSize.md,
          onPressed: saving ? null : () => _save(textOnly: true),
        ),
      ],
    ]);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.payload, required this.text});
  final SharePayload payload;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final files = payload.files;
    final images = files.where((f) => f.isImage).toList();
    return Container(
      padding: const EdgeInsets.all(Space.s300),
      decoration: BoxDecoration(
        color: c.bubbleSelf,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Radii.lg),
          topRight: Radius.circular(Radii.lg),
          bottomLeft: Radius.circular(Radii.lg),
          bottomRight: Radius.circular(Radii.xs),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: Space.s200),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Image.file(
                  File(images[i].path),
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  cacheWidth: 288,
                  errorBuilder: (_, __, ___) => Container(width: 96, height: 96, color: c.surfaceSunken),
                ),
              ),
            ),
          ),
        for (final f in files.where((f) => !f.isImage).take(3))
          Padding(
            padding: const EdgeInsets.only(top: Space.s200),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(
                  f.isVideo
                      ? TibbIcons.play
                      : f.isAudio
                          ? TibbIcons.fileAudio
                          : f.mime == 'application/pdf'
                              ? TibbIcons.filePdf
                              : f.isZip
                                  ? TibbIcons.fileZip
                                  : TibbIcons.file,
                  size: 20,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: Space.s300),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleXs.copyWith(color: c.bubbleSelfText)),
                  Text(formatBytes(f.size), style: t.monoSm.copyWith(color: c.bubbleSelfMeta)),
                ]),
              ),
            ]),
          ),
        if (files.where((f) => !f.isImage).length > 3)
          Padding(
            padding: const EdgeInsets.only(top: Space.s200),
            child: Text('and ${files.where((f) => !f.isImage).length - 3} more',
                style: t.caption.copyWith(color: c.bubbleSelfMeta)),
          ),
        if (text.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: files.isEmpty ? 0 : Space.s300),
            child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodyLg.copyWith(color: c.bubbleSelfText)),
          ),
        const SizedBox(height: Space.s100),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            [
              if (images.isNotEmpty) '${images.length} photo${images.length == 1 ? '' : 's'}',
              if (files.length > images.length) '${files.length - images.length} file${files.length - images.length == 1 ? '' : 's'}',
              if (text.isNotEmpty) isSingleUrl(text) ? 'link' : 'text',
            ].join(' · '),
            style: t.caption.copyWith(color: c.bubbleSelfMeta),
          ),
        ),
      ]),
    );
  }
}
