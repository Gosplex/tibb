// Thread bubbles (design §9.3). Self (this phone) = right, saffron; other
// devices = left, surface + hairline, labeled. The last bubble of a group has
// the "tucked" 6px corner on its origin side.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/models.dart';
import '../../core/util/format.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../items/item_viewers.dart';
import '../voice/voice_bubble.dart';

class Bubble extends StatelessWidget {
  const Bubble({
    super.key,
    required this.item,
    required this.isSelf,
    required this.tail,
    this.showUnreviewedDot = false,
    this.animateIn = false,
    this.onLongPress,
  });

  final Item item;
  final bool isSelf;
  final bool tail;
  final bool showUnreviewedDot;
  final bool animateIn;
  final VoidCallback? onLongPress;

  BorderRadius _radius() {
    const r = Radius.circular(Radii.lg);
    const tucked = Radius.circular(Radii.xs);
    if (!tail) return const BorderRadius.all(r);
    return isSelf
        ? const BorderRadius.only(topLeft: r, topRight: r, bottomLeft: r, bottomRight: tucked)
        : const BorderRadius.only(topLeft: r, topRight: r, bottomLeft: tucked, bottomRight: r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final isMedia = item.type == ItemType.image || item.type == ItemType.video;
    final maxWidth = width * (isMedia ? Sizes.mediaMaxWidthPct : Sizes.bubbleMaxWidthPct);
    final bg = isSelf ? c.bubbleSelf : c.bubbleOther;
    final fg = isSelf ? c.bubbleSelfText : c.textPrimary;
    final meta = isSelf ? c.bubbleSelfMeta : c.textTertiary;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: isMedia ? const EdgeInsets.all(Space.s100) : const EdgeInsets.fromLTRB(12, 9, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _radius(),
        border: isSelf ? null : Border.all(color: c.bubbleOtherBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _content(context, fg, meta),
          if (item.note != null && item.note!.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(isMedia ? Space.s200 : 0, Space.s100, isMedia ? Space.s200 : 0, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(TibbIcons.note, size: 12, color: meta),
                const SizedBox(width: Space.s100),
                Flexible(child: Text(item.note!, style: context.type.bodySm.copyWith(color: isSelf ? fg : c.textSecondary))),
              ]),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMedia ? Space.s200 : 0, Space.s050, isMedia ? Space.s200 : 0, isMedia ? Space.s100 : 0),
            child: _Meta(item: item, color: meta),
          ),
        ],
      ),
    );

    final row = Row(
      mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isSelf && showUnreviewedDot) const _UnreviewedDot(),
        Flexible(
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Semantics(
              label: _semanticLabel(),
              child: bubble,
            ),
          ),
        ),
        if (!isSelf && showUnreviewedDot) const _UnreviewedDot(),
      ],
    );

    if (!animateIn) return row;
    return _LandIn(fromLeft: !isSelf, child: row);
  }

  String _semanticLabel() {
    final who = isSelf ? 'From this phone' : 'From ${item.originDeviceName ?? 'another device'}';
    final what = switch (item.type) {
      ItemType.image => 'Photo',
      ItemType.video => 'Video',
      ItemType.voice => 'Voice memo, ${formatDuration(Duration(milliseconds: item.durationMs ?? 0))}',
      ItemType.file => 'File, ${item.fileName ?? ''}, ${formatBytes(item.size)}',
      ItemType.link => 'Link, ${item.text ?? ''}',
      _ => item.text ?? '',
    };
    final flags = [
      if (!item.reviewed) 'Unreviewed',
      if (item.pinned) 'Pinned',
    ].join('. ');
    return '$who, ${formatTime(item.createdAt)}. $what. $flags';
  }

  Widget _content(BuildContext context, Color fg, Color meta) {
    final repo = AppScope.of(context).repo;
    switch (item.type) {
      case ItemType.image:
        final path = repo.blobs.pathFor(item.blobHash!, item.mime);
        return GestureDetector(
          onTap: () => openImageViewer(context, item, path),
          child: Hero(
            tag: 'img-${item.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360, minWidth: 120, minHeight: 80),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                    opacity: sync || frame != null ? 1 : 0,
                    duration: context.motion(const Duration(milliseconds: 120)),
                    child: child,
                  ),
                  errorBuilder: (context, _, __) => _MissingMedia(color: meta),
                ),
              ),
            ),
          ),
        );
      case ItemType.video:
        return GestureDetector(
          onTap: () => openVideoViewer(context, item, repo.blobs.pathFor(item.blobHash!, item.mime)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 220,
              height: 160,
              color: Colors.black,
              alignment: Alignment.center,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.64), shape: BoxShape.circle),
                child: const Icon(TibbIcons.play, color: Colors.white, size: 24),
              ),
            ),
          ),
        );
      case ItemType.voice:
        return VoiceBubbleContent(item: item, fg: fg, meta: meta, isSelf: isSelf);
      case ItemType.file:
        return _FileContent(item: item, fg: fg, meta: meta);
      case ItemType.link:
        return _LinkContent(url: item.text ?? '', fg: fg, meta: meta);
      case ItemType.text:
      case ItemType.clipboard:
        return _LinkifiedText(text: item.text ?? '', style: context.type.bodyLg.copyWith(color: fg));
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.item, required this.color});
  final Item item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = context.type.caption.copyWith(color: color);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (item.source == 'whatsapp') ...[Text('WhatsApp ·', style: style), const SizedBox(width: Space.s100)],
      if (item.pinned) ...[Icon(TibbIcons.pinFill, size: 12, color: color), const SizedBox(width: Space.s100)],
      Text(formatTime(item.createdAt), style: style),
    ]);
  }
}

class _UnreviewedDot extends StatelessWidget {
  const _UnreviewedDot();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s200),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: c.unreviewedDot,
          shape: BoxShape.circle,
          // Ring keeps the dot visible to colorblind users (design §04).
          border: c.isDark ? null : Border.all(color: c.unreviewedRing, width: 1),
        ),
      ),
    );
  }
}

class _LinkifiedText extends StatefulWidget {
  const _LinkifiedText({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  bool _expanded = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in findUrls(widget.text)) {
      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      final url = m.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        recognizer: recognizer,
        style: const TextStyle(decoration: TextDecoration.underline),
      ));
      last = m.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));

    final long = '\n'.allMatches(widget.text).length > 11 || widget.text.length > 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(style: widget.style, children: spans),
          maxLines: long && !_expanded ? 12 : null,
          overflow: long && !_expanded ? TextOverflow.fade : null,
        ),
        if (long)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s100),
              child: Text(_expanded ? 'Show less' : 'Show more',
                  style: context.type.labelMd.copyWith(
                      color: widget.style.color, decoration: TextDecoration.underline)),
            ),
          ),
      ],
    );
  }
}

class _LinkContent extends StatelessWidget {
  const _LinkContent({required this.url, required this.fg, required this.meta});
  final String url;
  final Color fg;
  final Color meta;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    return InkWell(
      onTap: uri == null ? null : () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(TibbIcons.link, size: 20, color: fg)),
        const SizedBox(width: Space.s200),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(uri?.host ?? url, style: context.type.labelMd.copyWith(color: meta)),
            Text(url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodyMd.copyWith(color: fg, decoration: TextDecoration.underline)),
          ]),
        ),
      ]),
    );
  }
}

class _FileContent extends StatelessWidget {
  const _FileContent({required this.item, required this.fg, required this.meta});
  final Item item;
  final Color fg;
  final Color meta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = item.fileName ?? 'File';
    final icon = switch (item.mime) {
      'application/pdf' => TibbIcons.filePdf,
      'application/zip' => TibbIcons.fileZip,
      _ => TibbIcons.file,
    };
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
    return InkWell(
      onTap: () => openFileExternally(context, item),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
          child: Icon(icon, size: 24, color: fg),
        ),
        const SizedBox(width: Space.s300),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_middleEllipsis(name, 28), style: context.type.titleXs.copyWith(color: fg)),
            Text('${formatBytes(item.size)} · $ext', style: context.type.monoSm.copyWith(color: meta)),
          ]),
        ),
      ]),
    );
  }

  /// Keeps the extension visible: "very-long-invo…ice.pdf".
  static String _middleEllipsis(String s, int max) {
    if (s.length <= max) return s;
    final keep = (max - 1) ~/ 2;
    return '${s.substring(0, keep)}…${s.substring(s.length - keep)}';
  }
}

class _MissingMedia extends StatelessWidget {
  const _MissingMedia({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        height: 120,
        child: Center(child: Icon(TibbIcons.image, color: color, size: 32)),
      );
}

/// "The Land" (design §10.4): items settle in from the composer; items from a
/// computer arrive from the left. Reduced motion → a short fade only.
class _LandIn extends StatelessWidget {
  const _LandIn({required this.child, required this.fromLeft});
  final Widget child;
  final bool fromLeft;

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? Motion.reduced : Motion.normal,
      curve: reduce ? Curves.linear : Motion.settle,
      builder: (context, t, child) {
        if (reduce) return Opacity(opacity: _unit(t), child: child);
        final dx = fromLeft ? -24 * (1 - t) : 0.0;
        final dy = fromLeft ? 0.0 : 16 * (1 - t);
        return Opacity(
          opacity: _unit(t),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(scale: fromLeft ? 1.0 : 0.96 + 0.04 * t, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

double _unit(double t) => t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
