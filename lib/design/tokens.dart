// Design tokens — the single source of truth for every visual value in Tibb.
// Mirrors docs/DESIGN_SYSTEM.md §16. Widgets must read these (usually through
// `context.tibb`) instead of hardcoding values.
import 'package:flutter/material.dart';

/// Spacing scale (base unit 4). No values outside this scale (design RULE 7.1).
abstract final class Space {
  static const double s0 = 0;
  static const double s050 = 2;
  static const double s100 = 4;
  static const double s150 = 6;
  static const double s200 = 8;
  static const double s300 = 12;
  static const double s400 = 16;
  static const double s500 = 20;
  static const double s600 = 24;
  static const double s800 = 32;
  static const double s1000 = 40;
  static const double s1200 = 48;
  static const double s1600 = 64;
}

abstract final class Radii {
  static const double xs = 6; // tucked bubble corner, tags
  static const double sm = 10; // inputs, toasts
  static const double md = 14; // box tiles, thumbnails, menus
  static const double lg = 20; // bubbles, cards, banners
  static const double xl = 28; // sheets, dialogs
  static const double full = 999;
}

abstract final class Sizes {
  static const double touchTarget = 48;
  static const double appBar = 56;
  static const double composerMin = 56;
  static const double sendButton = 40;
  static const double buttonLg = 56;
  static const double buttonMd = 48;
  static const double buttonSm = 36;
  static const double input = 52;
  static const double search = 44;
  static const double boxTile = 40;
  static const double bubbleMaxWidthPct = 0.78;
  static const double mediaMaxWidthPct = 0.72;
  static const double threadMaxWidthTablet = 720;
  static const double dialogMaxWidth = 360;
}

abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration emphasis = Duration(milliseconds: 520);
  static const Duration reduced = Duration(milliseconds: 120);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve decelerate = Cubic(0, 0, 0, 1);
  static const Curve accelerate = Cubic(0.3, 0, 1, 1);

  /// "Settle, don't bounce": ~5% overshoot. Approximates spring.settle
  /// (mass 1, stiffness 420, damping 34) as a curve so it works in tweens.
  static const Curve settle = Cubic(0.2, 0.9, 0.25, 1.05);
}

abstract final class Opacities {
  static const double disabled = 0.38;
  static const double hover = 0.06;
  static const double pressed = 0.10;
  static const double focusTint = 0.12;
}

/// Raw palette. Only [TibbColors] should reference these directly.
abstract final class Palette {
  // Ink & paper
  static const ink950 = Color(0xFF121116);
  static const ink900 = Color(0xFF1C1A22);
  static const ink850 = Color(0xFF1B1A20);
  static const ink800 = Color(0xFF24222B);
  static const ink750 = Color(0xFF2D2B35);
  static const ink700 = Color(0xFF34313D);
  static const ink600 = Color(0xFF5E5866);
  static const ink550 = Color(0xFF6A6474);
  static const ink500 = Color(0xFF6F6876);
  static const ink450 = Color(0xFF8B8392);
  static const ink400 = Color(0xFF8E8797);
  static const ink300 = Color(0xFFB7B0BE);
  static const ink200 = Color(0xFFB8B1C0);
  static const paper300 = Color(0xFFCFC7B9);
  static const paper200 = Color(0xFFE3DDD2);
  static const paper150 = Color(0xFFEFEBE3);
  static const paper100 = Color(0xFFF7F4EE);
  static const paper50 = Color(0xFFFFFFFF);
  static const paperDark = Color(0xFFF2EEE8);

  // Saffron
  static const saffron50 = Color(0xFFFFF8E6);
  static const saffron100 = Color(0xFFFCE9B8);
  static const saffron300 = Color(0xFFF7C552);
  static const saffron400 = Color(0xFFF5B324);
  static const saffron450 = Color(0xFFF2B33D);
  static const saffron500 = Color(0xFFE09A0B);
  static const saffron700 = Color(0xFF8A5A06);
  static const saffron900 = Color(0xFF3A2F1A);
}

/// Box accent swatches: [light, dark]. Tiles, dots and thin rules only.
enum BoxAccent {
  saffron(Color(0xFFF5B324), Color(0xFFF2B33D)),
  coral(Color(0xFFE8664F), Color(0xFFF08A76)),
  rose(Color(0xFFD9477E), Color(0xFFEE7AA3)),
  plum(Color(0xFF7B5CE6), Color(0xFFA796FF)),
  ocean(Color(0xFF2F7DD6), Color(0xFF7FB2F5)),
  teal(Color(0xFF13A08C), Color(0xFF3CC7B3)),
  leaf(Color(0xFF4E9A3A), Color(0xFF86C96F)),
  slate(Color(0xFF6E7580), Color(0xFFA4ABB6));

  const BoxAccent(this.light, this.dark);
  final Color light;
  final Color dark;

  Color resolve(Brightness b) => b == Brightness.dark ? dark : light;

  static BoxAccent fromName(String? name) =>
      BoxAccent.values.firstWhere((a) => a.name == name, orElse: () => BoxAccent.saffron);
}
