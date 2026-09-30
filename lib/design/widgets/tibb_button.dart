import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';

enum TibbButtonVariant { primary, secondary, tertiary, ghost, destructive }

enum TibbButtonSize { lg, md, sm }

/// The one button component (design §9.1). At most one primary per screen.
class TibbButton extends StatefulWidget {
  const TibbButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TibbButtonVariant.primary,
    this.size = TibbButtonSize.lg,
    this.icon,
    this.loading = false,
    this.success = false,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final TibbButtonVariant variant;
  final TibbButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool success;
  final bool expand;
  final String? semanticLabel;

  @override
  State<TibbButton> createState() => _TibbButtonState();
}

class _TibbButtonState extends State<TibbButton> {
  bool _pressed = false;

  double get _height => switch (widget.size) {
        TibbButtonSize.lg => widget.variant == TibbButtonVariant.primary ||
                widget.variant == TibbButtonVariant.secondary
            ? Sizes.buttonLg
            : Sizes.buttonMd,
        TibbButtonSize.md => widget.variant == TibbButtonVariant.primary ||
                widget.variant == TibbButtonVariant.secondary
            ? Sizes.buttonMd
            : 40,
        TibbButtonSize.sm => Sizes.buttonSm,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final enabled = widget.onPressed != null && !widget.loading && !widget.success;

    final (Color bg, Color fg, BorderSide? border) = switch (widget.variant) {
      TibbButtonVariant.primary => (_pressed ? c.actionPrimaryPressed : c.actionPrimary, c.textOnAccent, null),
      TibbButtonVariant.secondary => (_pressed ? c.actionSecondaryPressed : c.actionSecondary, c.onActionSecondary, null),
      TibbButtonVariant.tertiary => (_pressed ? c.pressedOverlay : Colors.transparent, c.textPrimary, BorderSide(color: c.borderDefault)),
      TibbButtonVariant.ghost => (_pressed ? c.pressedOverlay : Colors.transparent, c.textPrimary, null),
      TibbButtonVariant.destructive => (
          c.isDark ? const Color(0xFFC0352D) : c.errorFg,
          Colors.white,
          null
        ),
    };

    final disabled = widget.onPressed == null;
    final effectiveBg = disabled && (widget.variant == TibbButtonVariant.primary || widget.variant == TibbButtonVariant.secondary)
        ? c.surfaceSunken
        : bg;
    final effectiveFg = disabled ? fg.withValues(alpha: Opacities.disabled) : fg;
    final style = widget.size == TibbButtonSize.lg ? t.buttonLg : t.buttonMd;
    final pad = switch (widget.size) {
      TibbButtonSize.lg => Space.s600,
      TibbButtonSize.md => Space.s500,
      TibbButtonSize.sm => 14.0,
    };

    Widget content;
    if (widget.success) {
      content = Icon(TibbIcons.check, color: effectiveFg, size: 22, key: const ValueKey('ok'));
    } else if (widget.loading) {
      content = SizedBox(
        key: const ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: effectiveFg),
      );
    } else {
      content = Row(
        key: const ValueKey('label'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: effectiveFg),
            const SizedBox(width: Space.s200),
          ],
          Flexible(
            child: Text(
              widget.label,
              style: style.copyWith(color: effectiveFg),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final button = AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: context.motion(Motion.fast),
      curve: Motion.standard,
      child: AnimatedContainer(
        duration: context.motion(Motion.instant),
        constraints: BoxConstraints(minHeight: _height, minWidth: widget.expand ? double.infinity : 72),
        padding: EdgeInsets.symmetric(horizontal: pad),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(Radii.full),
          border: border == null ? null : Border.fromBorderSide(border),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(duration: context.motion(Motion.normal), child: content),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: enabled
            ? () {
                if (widget.variant == TibbButtonVariant.primary) HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        // Keep a 48dp hit area even for the small visual size (design RULE).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.touchTarget),
          child: Center(widthFactor: widget.expand ? null : 1, child: button),
        ),
      ),
    );
  }
}

/// Icon-only button with a guaranteed 48dp target and a semantic label.
class TibbIconButton extends StatelessWidget {
  const TibbIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.filled = false,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool filled;

  /// Shows a small connected ring (used for an active Bridge session).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: SizedBox(
            width: Sizes.touchTarget,
            height: Sizes.touchTarget,
            child: Center(
              child: Container(
                width: filled ? 44 : null,
                height: filled ? 44 : null,
                decoration: filled
                    ? BoxDecoration(color: c.surfaceSunken, shape: BoxShape.circle)
                    : badge
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.connectedFg, width: 2),
                          )
                        : null,
                padding: badge ? const EdgeInsets.all(Space.s100) : null,
                child: Icon(icon, size: 24, color: color ?? c.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
