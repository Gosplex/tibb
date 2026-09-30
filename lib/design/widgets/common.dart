// Small shared components: sheet shell, toast, info card, empty state, box tile,
// tag, section label. Screens compose these instead of styling ad hoc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';

/// Presents content in Tibb's bottom sheet shell (design §9.8).
Future<T?> showTibbSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool fullHeight = false,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    sheetAnimationStyle: AnimationStyle(
      duration: context.motion(const Duration(milliseconds: 300)),
      reverseDuration: context.motion(const Duration(milliseconds: 200)),
    ),
    builder: (ctx) {
      final child = builder(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: fullHeight
            ? SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.94, child: child)
            : child,
      );
    },
  );
}

/// Sheet body with grabber and title.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, this.title, required this.child, this.trailing, this.scrollable = true});

  final String? title;
  final Widget child;
  final Widget? trailing;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(Space.s500, Space.s300, Space.s500, Space.s500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: Space.s300),
            Row(children: [
              Expanded(child: Semantics(header: true, child: Text(title!, style: context.type.titleMd))),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: Space.s600),
          ] else
            const SizedBox(height: Space.s400),
          if (scrollable) Flexible(child: SingleChildScrollView(child: child)) else child,
        ],
      ),
    );
    return SafeArea(top: false, child: body);
  }
}

/// Toast / snackbar (design §9.7). Auto-dismiss 4 s, or 8 s with an action.
void showToast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: Duration(seconds: actionLabel == null ? 4 : 8),
    margin: const EdgeInsets.fromLTRB(Space.s400, 0, Space.s400, Space.s400),
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}

enum InfoTone { info, connected, private, warning, error, success }

/// Info / status card with semantic tint (design §9.4).
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.tone, required this.title, this.body, this.icon, this.action});

  final InfoTone tone;
  final String title;
  final String? body;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fg, Color bg, IconData defaultIcon) = switch (tone) {
      InfoTone.info => (c.infoFg, c.infoBg, TibbIcons.info),
      InfoTone.connected => (c.connectedFg, c.connectedBg, TibbIcons.bridge),
      InfoTone.private => (c.privateFg, c.privateBg, TibbIcons.lock),
      InfoTone.warning => (c.warningFg, c.warningBg, TibbIcons.warning),
      InfoTone.error => (c.errorFg, c.errorBg, TibbIcons.warning),
      InfoTone.success => (c.successFg, c.successBg, TibbIcons.checkCircle),
    };
    return Container(
      padding: const EdgeInsets.all(Space.s400),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 20, color: fg),
          const SizedBox(width: Space.s300),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.titleXs.copyWith(color: c.textPrimary)),
                if (body != null) ...[
                  const SizedBox(height: Space.s100),
                  Text(body!, style: context.type.bodySm.copyWith(color: c.textSecondary)),
                ],
                if (action != null) ...[const SizedBox(height: Space.s200), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state (design §9 / §20): never a dead end.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.art, required this.headline, required this.body, this.action});

  final Widget? art;
  final String headline;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s600, Space.s1200, Space.s600, Space.s600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art != null) ...[ExcludeSemantics(child: art!), const SizedBox(height: Space.s600)],
          Text(headline, style: context.type.headlineHero, textAlign: TextAlign.center),
          const SizedBox(height: Space.s200),
          Text(body, style: context.type.bodyMd.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: Space.s600), action!],
        ],
      ),
    );
  }
}

/// Emoji box tile on its accent tint (design §8.1).
class BoxTile extends StatelessWidget {
  const BoxTile({super.key, required this.box, this.size = Sizes.boxTile});

  final Box box;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = BoxAccent.fromName(box.color).resolve(c.brightness);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: c.isDark ? 0.24 : 0.16),
          borderRadius: BorderRadius.circular(Radii.md * size / Sizes.boxTile),
        ),
        child: Text(box.emoji, style: TextStyle(fontSize: size * 0.55, height: 1)),
      ),
    );
  }
}

/// Small tag, e.g. "Launch price", "Pro", "Locked".
class TibbTag extends StatelessWidget {
  const TibbTag({super.key, required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: Space.s200),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.xs)),
        child: Text(label, style: context.type.promo.copyWith(color: fg)),
      );
}

/// Section label for settings groups (overline, sparingly).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.s100, Space.s600, Space.s100, Space.s200),
        child: Semantics(
          header: true,
          child: Text(text.toUpperCase(), style: context.type.overline.copyWith(color: context.colors.textTertiary)),
        ),
      );
}

/// Group of rows inside one card, separated by inset hairlines.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(indent: Space.s400 + 24 + Space.s300, height: 1, color: c.borderSubtle));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? null : Border.all(color: c.borderSubtle),
      ),
      child: Column(children: rows),
    );
  }
}

/// Settings-style row: icon + title + optional value + chevron/trailing.
class TibbRow extends StatelessWidget {
  const TibbRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = destructive ? c.errorFg : c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s400, vertical: Space.s300),
          child: Row(
            children: [
              Icon(icon, size: 24, color: destructive ? c.errorFg : c.textSecondary),
              const SizedBox(width: Space.s300),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.type.bodyMd.copyWith(color: color)),
                    if (subtitle != null)
                      Text(subtitle!, style: context.type.bodySm.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
              if (value != null) ...[
                Text(value!, style: context.type.bodyMd.copyWith(color: c.textTertiary)),
                const SizedBox(width: Space.s200),
              ],
              trailing ?? (onTap != null ? Icon(TibbIcons.caretRight, size: 16, color: c.textTertiary) : const SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand mark from the logo (box with lid). Decorative.
class TibbMark extends StatelessWidget {
  const TibbMark({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Image.asset('assets/brand/tibb_mark.png', width: size, height: size, fit: BoxFit.contain),
      );
}

/// Segmented control (design §9.2): sunken track, raised selected segment
/// that slides over 240 ms. Used for theme and the WhatsApp date order.
class TibbSegmented<T> extends StatelessWidget {
  const TibbSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = segments.indexWhere((s) => s.$1 == selected).clamp(0, segments.length - 1);
    return LayoutBuilder(builder: (context, box) {
      return Container(
        height: 40,
        padding: const EdgeInsets.all(Space.s050),
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.sm)),
        child: Stack(children: [
          AnimatedAlign(
            duration: context.motion(Motion.normal),
            curve: Motion.standard,
            alignment: Alignment(segments.length == 1 ? 0 : -1 + 2 * index / (segments.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / segments.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: c.isDark ? c.surfaceOverlay : c.surface,
                  borderRadius: BorderRadius.circular(Radii.sm - 2),
                  boxShadow: c.isDark ? null : const [BoxShadow(color: Color(0x0F1C1A22), blurRadius: 2, offset: Offset(0, 1))],
                ),
              ),
            ),
          ),
          Row(children: [
            for (final (value, label) in segments)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == selected,
                  label: label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onChanged == null || value == selected
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onChanged!(value);
                          },
                    child: Center(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.labelLg.copyWith(
                            color: value == selected ? c.textPrimary : c.textSecondary,
                          )),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      );
    });
  }
}

/// Determinate progress (design §9.11): 6 high, saffron fill, percentage in mono.
class TibbProgress extends StatelessWidget {
  const TibbProgress({super.key, required this.value, this.label});

  /// 0…1, or null for "working on it" (a slow shimmer-free indeterminate bar).
  final double? value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.full),
        child: SizedBox(
          height: 6,
          child: value == null
              ? LinearProgressIndicator(backgroundColor: c.surfaceSunken, color: c.actionPrimary, minHeight: 6)
              : Stack(children: [
                  Container(color: c.surfaceSunken),
                  AnimatedFractionallySizedBox(
                    duration: context.motion(Motion.normal),
                    curve: Motion.standard,
                    widthFactor: value!.clamp(0.0, 1.0),
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: Container(color: c.actionPrimary),
                  ),
                ]),
        ),
      ),
      if (label != null || value != null) ...[
        const SizedBox(height: Space.s200),
        Row(children: [
          if (label != null)
            Expanded(child: Text(label!, style: context.type.bodySm.copyWith(color: c.textSecondary))),
          if (value != null) Text('${(value!.clamp(0.0, 1.0) * 100).round()}%', style: context.type.monoSm.copyWith(color: c.textTertiary)),
        ]),
      ],
    ]);
  }
}
