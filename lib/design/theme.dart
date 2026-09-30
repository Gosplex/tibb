// Theme construction. Light and dark are both first-class and intentionally
// designed ("Ink at night" — see docs/DESIGN_SYSTEM.md §05), not inverted.
import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic color tokens (design system §04 / §05).
@immutable
class TibbColors extends ThemeExtension<TibbColors> {
  const TibbColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.surfaceInverse,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnAccent,
    required this.textOnInverse,
    required this.textAccent,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderInput,
    required this.borderFocus,
    required this.borderSelected,
    required this.actionPrimary,
    required this.actionPrimaryPressed,
    required this.actionSecondary,
    required this.actionSecondaryPressed,
    required this.onActionSecondary,
    required this.actionDestructive,
    required this.bubbleSelf,
    required this.bubbleSelfText,
    required this.bubbleSelfMeta,
    required this.bubbleOther,
    required this.bubbleOtherBorder,
    required this.unreviewedDot,
    required this.unreviewedRing,
    required this.privateFg,
    required this.privateBg,
    required this.connectedFg,
    required this.connectedBg,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.errorFg,
    required this.errorBg,
    required this.infoFg,
    required this.infoBg,
    required this.scrim,
    required this.pressedOverlay,
    required this.highlight,
    required this.skeletonBase,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceSunken;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color surfaceInverse;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textOnAccent;
  final Color textOnInverse;
  final Color textAccent;
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderInput;
  final Color borderFocus;
  final Color borderSelected;
  final Color actionPrimary;
  final Color actionPrimaryPressed;
  final Color actionSecondary;
  final Color actionSecondaryPressed;
  final Color onActionSecondary;
  final Color actionDestructive;
  final Color bubbleSelf;
  final Color bubbleSelfText;
  final Color bubbleSelfMeta;
  final Color bubbleOther;
  final Color bubbleOtherBorder;
  final Color unreviewedDot;
  final Color unreviewedRing;
  final Color privateFg;
  final Color privateBg;
  final Color connectedFg;
  final Color connectedBg;
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color errorFg;
  final Color errorBg;
  final Color infoFg;
  final Color infoBg;
  final Color scrim;
  final Color pressedOverlay;

  /// Search-match / arrival highlight (saffron.100 light, saffron.900 dark).
  final Color highlight;
  final Color skeletonBase;

  bool get isDark => brightness == Brightness.dark;

  static const light = TibbColors(
    brightness: Brightness.light,
    background: Palette.paper100,
    surface: Palette.paper50,
    surfaceSunken: Palette.paper150,
    surfaceRaised: Palette.paper50,
    surfaceOverlay: Palette.paper50,
    surfaceInverse: Palette.ink900,
    textPrimary: Palette.ink900,
    textSecondary: Palette.ink600,
    textTertiary: Palette.ink500,
    textDisabled: Palette.ink300,
    textOnAccent: Palette.ink900,
    textOnInverse: Palette.paperDark,
    textAccent: Palette.saffron700,
    borderSubtle: Palette.paper200,
    borderDefault: Palette.paper300,
    borderInput: Palette.ink450,
    borderFocus: Palette.ink900,
    borderSelected: Palette.saffron400,
    actionPrimary: Palette.saffron400,
    actionPrimaryPressed: Palette.saffron500,
    actionSecondary: Palette.ink900,
    actionSecondaryPressed: Palette.ink700,
    onActionSecondary: Palette.paperDark,
    actionDestructive: Color(0xFFC0352D),
    bubbleSelf: Palette.saffron100,
    bubbleSelfText: Palette.ink900,
    bubbleSelfMeta: Color(0xFF6E6452),
    bubbleOther: Palette.paper50,
    bubbleOtherBorder: Palette.paper200,
    unreviewedDot: Palette.saffron400,
    unreviewedRing: Palette.saffron700,
    privateFg: Color(0xFF5B3FD1),
    privateBg: Color(0xFFEFEAFF),
    connectedFg: Color(0xFF0A7366),
    connectedBg: Color(0xFFE3F6F2),
    successFg: Color(0xFF1D7F47),
    successBg: Color(0xFFE4F4EA),
    warningFg: Color(0xFF9A5B00),
    warningBg: Color(0xFFFFF1D9),
    errorFg: Color(0xFFC0352D),
    errorBg: Color(0xFFFCE9E7),
    infoFg: Color(0xFF2A62C9),
    infoBg: Color(0xFFE6EEFC),
    scrim: Color(0x521C1A22), // ink.900 @ 0.32
    pressedOverlay: Color(0x1A1C1A22), // ink.900 @ 0.10
    highlight: Palette.saffron100,
    skeletonBase: Palette.paper150,
  );

  static const dark = TibbColors(
    brightness: Brightness.dark,
    background: Palette.ink950,
    surface: Palette.ink850,
    surfaceSunken: Palette.ink800,
    surfaceRaised: Palette.ink800,
    surfaceOverlay: Palette.ink750,
    surfaceInverse: Palette.paperDark,
    textPrimary: Palette.paperDark,
    textSecondary: Palette.ink200,
    textTertiary: Palette.ink400,
    textDisabled: Color(0xFF5A5563),
    textOnAccent: Palette.ink950,
    textOnInverse: Palette.ink900,
    textAccent: Palette.saffron450,
    borderSubtle: Palette.ink750,
    borderDefault: Palette.ink700,
    borderInput: Palette.ink550,
    borderFocus: Palette.saffron450,
    borderSelected: Palette.saffron450,
    actionPrimary: Palette.saffron450,
    actionPrimaryPressed: Color(0xFFD99A24),
    actionSecondary: Palette.paperDark,
    actionSecondaryPressed: Color(0xFFD9D4CC),
    onActionSecondary: Palette.ink900,
    actionDestructive: Color(0xFFFF7A70),
    bubbleSelf: Palette.saffron900,
    bubbleSelfText: Color(0xFFF7ECD6),
    bubbleSelfMeta: Color(0xFFC9B68E),
    bubbleOther: Palette.ink850,
    bubbleOtherBorder: Palette.ink700,
    unreviewedDot: Palette.saffron450,
    unreviewedRing: Palette.saffron450,
    privateFg: Color(0xFFA796FF),
    privateBg: Color(0xFF2A2342),
    connectedFg: Color(0xFF3CC7B3),
    connectedBg: Color(0xFF11302C),
    successFg: Color(0xFF5BD08E),
    successBg: Color(0xFF12301F),
    warningFg: Color(0xFFF5B85A),
    warningBg: Color(0xFF3A2A10),
    errorFg: Color(0xFFFF7A70),
    errorBg: Color(0xFF3D1A18),
    infoFg: Color(0xFF7FAAFF),
    infoBg: Color(0xFF18233D),
    scrim: Color(0x8F000000), // black @ 0.56
    pressedOverlay: Color(0x1AF2EEE8),
    highlight: Palette.saffron900,
    skeletonBase: Palette.ink850,
  );

  @override
  TibbColors copyWith() => this;

  @override
  TibbColors lerp(ThemeExtension<TibbColors>? other, double t) {
    // Themes switch discretely; interpolating 45 tokens adds nothing visible.
    if (other is! TibbColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Typography tokens (design system §06). Figtree for UI, Fraunces only for
/// display moments (max once per screen), JetBrains Mono for addresses/codes.
@immutable
class TibbText extends ThemeExtension<TibbText> {
  const TibbText._(this._color);

  factory TibbText.forColors(TibbColors c) => TibbText._(c.textPrimary);

  final Color _color;

  static const _tabular = [FontFeature.tabularFigures()];

  TextStyle _ui(double size, double line, double weight, double tracking,
          {bool tabular = false}) =>
      TextStyle(
        fontFamily: 'Figtree',
        fontSize: size,
        height: line / size,
        letterSpacing: tracking * size,
        fontWeight: _nearestWeight(weight),
        fontVariations: [FontVariation('wght', weight)],
        fontFeatures: tabular ? _tabular : null,
        color: _color,
      );

  TextStyle _display(double size, double line, double tracking) => TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        height: line / size,
        letterSpacing: tracking * size,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600), FontVariation('SOFT', 100)],
        color: _color,
      );

  TextStyle _mono(double size, double line, double weight, double tracking) => TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: size,
        height: line / size,
        letterSpacing: tracking * size,
        fontWeight: _nearestWeight(weight),
        fontVariations: [FontVariation('wght', weight)],
        fontFeatures: _tabular,
        color: _color,
      );

  static FontWeight _nearestWeight(double w) {
    final i = ((w / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[i];
  }

  TextStyle get displayLg => _display(40, 44, -0.02);
  TextStyle get displayMd => _display(32, 38, -0.015);
  TextStyle get headlineHero => _display(26, 32, -0.01);
  TextStyle get titleLg => _ui(24, 30, 750, -0.01);
  TextStyle get titleMd => _ui(20, 26, 700, -0.005);
  TextStyle get titleSm => _ui(17, 22, 650, 0);
  TextStyle get titleXs => _ui(15, 20, 650, 0);
  TextStyle get overline => _ui(12, 16, 700, 0.06);
  TextStyle get bodyLg => _ui(17, 24, 450, 0);
  TextStyle get bodyMd => _ui(15, 21, 450, 0);
  TextStyle get bodySm => _ui(13, 18, 450, 0.005);
  TextStyle get caption => _ui(12, 16, 550, 0.01, tabular: true);
  TextStyle get labelLg => _ui(15, 20, 650, 0);
  TextStyle get labelMd => _ui(13, 16, 650, 0.01);
  TextStyle get buttonLg => _ui(17, 22, 700, 0);
  TextStyle get buttonMd => _ui(15, 20, 650, 0);
  TextStyle get input => _ui(17, 24, 450, 0);
  TextStyle get helper => _ui(13, 18, 450, 0);
  TextStyle get error => _ui(13, 18, 550, 0);
  TextStyle get monoXl => _mono(30, 36, 600, 0);
  TextStyle get monoLg => _mono(34, 40, 600, 0.02);
  TextStyle get monoMd => _mono(15, 20, 500, 0);
  TextStyle get monoSm => _mono(12, 16, 500, 0);
  TextStyle get numberPrice => _ui(28, 32, 800, -0.01, tabular: true);
  TextStyle get numberStat => _ui(22, 28, 750, 0, tabular: true);
  TextStyle get promo => _ui(13, 16, 750, 0.02);

  @override
  TibbText copyWith() => this;

  @override
  TibbText lerp(ThemeExtension<TibbText>? other, double t) =>
      other is TibbText && t >= 0.5 ? other : this;
}

ThemeData buildTheme(TibbColors c) {
  final text = TibbText.forColors(c);
  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.actionPrimary,
    onPrimary: c.textOnAccent,
    secondary: c.actionSecondary,
    onSecondary: c.onActionSecondary,
    error: c.errorFg,
    onError: c.isDark ? Palette.ink950 : Colors.white,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.surfaceSunken,
    outline: c.borderDefault,
    outlineVariant: c.borderSubtle,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: 'Figtree',
    splashFactory: NoSplash.splashFactory, // pressed states are designed per component
    extensions: [c, text],
    textTheme: TextTheme(
      displayLarge: text.displayLg,
      displayMedium: text.displayMd,
      headlineMedium: text.headlineHero,
      titleLarge: text.titleLg,
      titleMedium: text.titleMd,
      titleSmall: text.titleSm,
      bodyLarge: text.bodyLg,
      bodyMedium: text.bodyMd,
      bodySmall: text.bodySm,
      labelLarge: text.labelLg,
      labelMedium: text.labelMd,
      labelSmall: text.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleMd,
    ),
    iconTheme: IconThemeData(color: c.textPrimary, size: 24),
    dividerTheme: DividerThemeData(color: c.borderSubtle, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceOverlay,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceOverlay,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      titleTextStyle: text.titleMd,
      contentTextStyle: text.bodyMd.copyWith(color: c.textSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceInverse,
      contentTextStyle: text.bodyMd.copyWith(color: c.textOnInverse),
      actionTextColor: Palette.saffron450,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.isDark ? c.surfaceSunken : c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: text.input.copyWith(color: c.textTertiary),
      labelStyle: text.labelMd.copyWith(color: c.textSecondary),
      helperStyle: text.helper.copyWith(color: c.textTertiary),
      errorStyle: text.error.copyWith(color: c.errorFg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.borderInput),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.borderInput),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.borderFocus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.errorFg, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c.errorFg, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.textOnAccent : c.surface),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.actionPrimary : c.surfaceSunken),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.borderInput),
      // A check glyph inside the thumb, so on/off never relies on color alone.
      thumbIcon: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
          ? Icon(Icons.check_rounded, size: 16, color: c.actionPrimary)
          : null),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.textPrimary,
      selectionColor: c.highlight,
      selectionHandleColor: c.actionPrimary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
    }),
  );
}

extension TibbThemeX on BuildContext {
  TibbColors get colors => Theme.of(this).extension<TibbColors>()!;
  TibbText get type => Theme.of(this).extension<TibbText>()!;

  /// Reduced-motion aware duration (design system §10.5).
  Duration motion(Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false ? Motion.reduced : d;
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
