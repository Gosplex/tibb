// Spot illustrations (design §2.5): simple objects in a 2 px ink stroke with
// rounded caps and joins, flat saffron and paper fills, no people, no faces.
// Drawn in code (no SVG package) on a 160 × 120 canvas so they stay crisp at
// any size and follow the theme automatically.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum Illustration {
  /// An open box with a paper slip — empty thread, onboarding.
  openBox,

  /// A phone and a laptop on the same Wi-Fi arc — Bridge.
  phoneLaptop,

  /// Generic chat bubbles tipping into a box — WhatsApp import (no logos).
  chatToBox,

  /// A closed box with a padlock — locked boxes, privacy.
  lockedBox,

  /// A closed box, lid on — export, import done.
  closedBox,

  /// A slip landing in a box — share-in, "tucked away".
  tucked,
}

class TibbIllustration extends StatelessWidget {
  const TibbIllustration(this.kind, {super.key, this.width = 160, this.lid = 0});

  final Illustration kind;
  final double width;

  /// 0 = lid lifted, 1 = lid closed. Drives "The Lid" micro-motion (design §10.4).
  final double lid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final palette = _Palette(
      ink: c.textPrimary,
      saffron: c.actionPrimary,
      paper: c.isDark ? c.surfaceSunken : c.surface,
      sunken: c.isDark ? c.surfaceRaised : c.surfaceSunken,
      accent: c.connectedFg,
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width * 0.75,
        child: CustomPaint(painter: _IllustrationPainter(kind, palette, lid.clamp(0.0, 1.0))),
      ),
    );
  }
}

/// The lid closing over something just saved: plays once when built.
class LidClose extends StatelessWidget {
  const LidClose({super.key, this.kind = Illustration.tucked, this.width = 120});
  final Illustration kind;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return TibbIllustration(kind, width: width, lid: 1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.emphasis,
      curve: Motion.settle,
      builder: (_, v, __) => TibbIllustration(kind, width: width, lid: v),
    );
  }
}

class _Palette {
  const _Palette({required this.ink, required this.saffron, required this.paper, required this.sunken, required this.accent});
  final Color ink;
  final Color saffron;
  final Color paper;
  final Color sunken;
  final Color accent;
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter(this.kind, this.p, this.lid);

  final Illustration kind;
  final _Palette p;
  final double lid;

  late final Paint _stroke = Paint()
    ..color = p.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fill(Color c) => Paint()..color = c;

  void _shape(Canvas canvas, Path path, Color fill) {
    canvas.drawPath(path, _fill(fill));
    canvas.drawPath(path, _stroke);
  }

  Path _rrect(double l, double t, double r, double b, double radius) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 120);
    // Soft ground shadow shared by every scene.
    canvas.drawOval(const Rect.fromLTRB(28, 104, 132, 114), _fill(p.sunken));
    switch (kind) {
      case Illustration.openBox:
        _box(canvas, lidLift: 1 - lid, slip: true);
      case Illustration.tucked:
        _box(canvas, lidLift: 1 - lid, slip: true, slipDrop: lid);
      case Illustration.closedBox:
        _box(canvas, lidLift: 0, slip: false);
        _sparkles(canvas);
      case Illustration.lockedBox:
        _box(canvas, lidLift: 0, slip: false);
        _padlock(canvas, const Offset(80, 80));
      case Illustration.phoneLaptop:
        _phoneLaptop(canvas);
      case Illustration.chatToBox:
        _chatToBox(canvas);
    }
    canvas.restore();
  }

  /// Box body 40–120 × 58–104 with a lid that lifts and tilts by [lidLift].
  void _box(Canvas canvas, {required double lidLift, required bool slip, double slipDrop = 0}) {
    if (slip) {
      // The paper slip peeks out (or drops in as the lid closes).
      canvas.save();
      final dy = 18 * slipDrop;
      canvas.translate(80, 52 + dy);
      canvas.rotate(0.10 * (1 - slipDrop));
      final slipPath = _rrect(-16, -22, 16, 16, 4);
      _shape(canvas, slipPath, p.saffron);
      final line = Paint()
        ..color = p.ink.withValues(alpha: 0.55)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-8, -12), const Offset(8, -12), line);
      canvas.drawLine(const Offset(-8, -5), const Offset(4, -5), line);
      canvas.restore();
    }
    // Body with a front band.
    _shape(canvas, _rrect(40, 58, 120, 104, 10), p.paper);
    canvas.drawLine(const Offset(40, 70), const Offset(120, 70), _stroke);
    canvas.drawLine(const Offset(72, 82), const Offset(88, 82), _stroke);
    // Lid: hinged at the left, lifted and tilted when open.
    canvas.save();
    canvas.translate(36, 56);
    canvas.rotate(-0.32 * lidLift);
    canvas.translate(0, -6 * lidLift);
    _shape(canvas, _rrect(0, -12, 88, 2, 6), p.paper);
    canvas.restore();
  }

  void _padlock(Canvas canvas, Offset c) {
    final shackle = Path()
      ..moveTo(c.dx - 7, c.dy - 4)
      ..lineTo(c.dx - 7, c.dy - 9)
      ..arcToPoint(Offset(c.dx + 7, c.dy - 9), radius: const Radius.circular(7))
      ..lineTo(c.dx + 7, c.dy - 4);
    canvas.drawPath(shackle, _stroke);
    _shape(canvas, _rrect(c.dx - 11, c.dy - 5, c.dx + 11, c.dy + 12, 4), p.saffron);
    canvas.drawCircle(Offset(c.dx, c.dy + 3), 1.8, _fill(p.ink));
  }

  void _sparkles(Canvas canvas) {
    for (final (x, y, s) in const [(30.0, 40.0, 6.0), (128.0, 34.0, 8.0), (138.0, 62.0, 5.0)]) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.pi / 4);
      canvas.drawRRect(RRect.fromLTRBR(-s / 2, -s / 2, s / 2, s / 2, const Radius.circular(1.5)), _fill(p.saffron));
      canvas.restore();
    }
  }

  void _phoneLaptop(Canvas canvas) {
    // Laptop
    _shape(canvas, _rrect(70, 36, 146, 86, 6), p.paper);
    _shape(canvas, _rrect(76, 42, 140, 80, 3), p.sunken);
    final base = Path()
      ..moveTo(62, 90)
      ..lineTo(154, 90)
      ..lineTo(150, 96)
      ..quadraticBezierTo(149, 98, 146, 98)
      ..lineTo(70, 98)
      ..quadraticBezierTo(67, 98, 66, 96)
      ..close();
    _shape(canvas, base, p.paper);
    canvas.drawLine(const Offset(70, 86), const Offset(146, 86), _stroke);
    // The item that just landed on the computer.
    _shape(canvas, _rrect(96, 52, 120, 70, 3), p.saffron);
    // Phone
    _shape(canvas, _rrect(16, 46, 46, 100, 7), p.paper);
    canvas.drawLine(const Offset(26, 52), const Offset(36, 52), _stroke);
    _shape(canvas, _rrect(22, 62, 40, 76, 3), p.saffron);
    // Wi-Fi arcs between them.
    final arc = Paint()
      ..color = p.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const center = Offset(58, 44);
    for (final r in const [7.0, 14.0, 21.0]) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi * 0.78, math.pi * 0.56, false, arc);
    }
    canvas.drawCircle(center, 2.5, _fill(p.accent));
  }

  void _chatToBox(Canvas canvas) {
    // Two generic chat bubbles (no logos, no faces).
    final b1 = Path()
      ..addRRect(RRect.fromLTRBR(12, 20, 70, 44, const Radius.circular(10)))
      ..moveTo(20, 44)
      ..lineTo(16, 52)
      ..lineTo(28, 44);
    _shape(canvas, b1, p.paper);
    final dash = Paint()
      ..color = p.ink.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(22, 32), const Offset(58, 32), dash);
    _shape(canvas, _rrect(22, 56, 64, 74, 9), p.saffron);
    canvas.drawLine(const Offset(31, 65), const Offset(54, 65), dash);
    // Arrow into the box.
    final arrow = Path()
      ..moveTo(72, 64)
      ..quadraticBezierTo(84, 56, 92, 66);
    canvas.drawPath(arrow, _stroke);
    canvas.drawPath(
      Path()
        ..moveTo(86, 66)
        ..lineTo(92, 66)
        ..lineTo(92, 60),
      _stroke,
    );
    // Box on the right.
    _shape(canvas, _rrect(96, 64, 148, 104, 9), p.paper);
    canvas.drawLine(const Offset(96, 75), const Offset(148, 75), _stroke);
    _shape(canvas, _rrect(92, 52, 152, 64, 6), p.paper);
    _shape(canvas, _rrect(114, 82, 130, 96, 3), p.saffron);
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) => old.kind != kind || old.lid != lid || old.p.ink != p.ink;
}
