import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/camera_state.dart';

/// Preview media-frame effect (docs/04 §7): a Flutter-only overlay that
/// makes the preview read as "seen through that era's medium". No shader
/// changes; photos are NOT burned in during P1 (docs/08 §8.3).

/// Which frame decorates the preview. Bands follow the docs/04 §7 table,
/// evaluated on the decade-quantized year.
enum MediaFrameStyle {
  /// No frame (the digital era and the 1890-1920 gap of the table).
  none,

  /// 1930-1970: white border with slightly rounded corners (silver print).
  silverPrint,

  /// The 1950s: silver print with a deckle (scalloped) edge.
  deckle,

  /// 1845-1890: cardboard mount with an oval window (portrait-studio card).
  cardMount,

  /// 1500-1840: paper margin with a plate rule line (printed engraving).
  engravingPlate,

  /// 1000-1500: mounting bands of a picture scroll; rollers in landscape.
  scroll,
}

/// Pure band lookup (docs/04 §7 table) on the quantized year.
MediaFrameStyle frameStyleForYear(int quantizedYear) {
  if (quantizedYear == 1950) return MediaFrameStyle.deckle;
  if (quantizedYear >= 1930 && quantizedYear <= 1970) {
    return MediaFrameStyle.silverPrint;
  }
  // The 1845 table edge lands on the 1850 decade after quantization.
  if (quantizedYear >= 1850 && quantizedYear <= 1890) {
    return MediaFrameStyle.cardMount;
  }
  if (quantizedYear >= 1500 && quantizedYear <= 1840) {
    return MediaFrameStyle.engravingPlate;
  }
  if (quantizedYear < 1500) return MediaFrameStyle.scroll;
  return MediaFrameStyle.none;
}

/// Stack layer for CameraScreen. Crossfades between frames over 300 ms when
/// the era band changes (docs/04 §7).
class MediaFrameOverlay extends ConsumerStatefulWidget {
  const MediaFrameOverlay({super.key});

  static const crossfadeDuration = Duration(milliseconds: 300);

  @override
  ConsumerState<MediaFrameOverlay> createState() => _MediaFrameOverlayState();
}

class _MediaFrameOverlayState extends ConsumerState<MediaFrameOverlay> {
  MediaFrameStyle? _lastStyle;
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final quantizedYear = ref.watch(
      cameraNotifierProvider.select((s) => s.quantizedYear),
    );
    final style = frameStyleForYear(quantizedYear);
    if (style != _lastStyle) {
      _lastStyle = style;
      // A fast slider drag can re-enter a style while its previous entry is
      // still fading out; keying the switcher child by style alone would
      // then put duplicate keys in the AnimatedSwitcher's stack.
      _generation++;
    }
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: MediaFrameOverlay.crossfadeDuration,
        child: KeyedSubtree(
          key: ValueKey('$style#$_generation'),
          child: style == MediaFrameStyle.none
              ? SizedBox.expand(key: ValueKey(style))
              : OrientationBuilder(
                  key: ValueKey(style),
                  builder: (context, orientation) => CustomPaint(
                    size: Size.infinite,
                    painter: _painterFor(style, orientation),
                  ),
                ),
        ),
      ),
    );
  }

  CustomPainter _painterFor(MediaFrameStyle style, Orientation orientation) {
    switch (style) {
      case MediaFrameStyle.silverPrint:
        return const _PrintFramePainter(deckle: false);
      case MediaFrameStyle.deckle:
        return const _PrintFramePainter(deckle: true);
      case MediaFrameStyle.cardMount:
        return const _CardMountPainter();
      case MediaFrameStyle.engravingPlate:
        return const _EngravingPlatePainter();
      case MediaFrameStyle.scroll:
        return _ScrollPainter(orientation);
      case MediaFrameStyle.none:
        throw StateError('none has no painter');
    }
  }
}

/// White silver-print border; optional deckle (scalloped) inner edge.
class _PrintFramePainter extends CustomPainter {
  const _PrintFramePainter({required this.deckle});

  final bool deckle;

  @override
  void paint(Canvas canvas, Size size) {
    final border = math.max(10.0, size.shortestSide * 0.035);
    final inner = Rect.fromLTWH(
      border, border, size.width - border * 2, size.height - border * 2);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (deckle) {
      path.addPath(_deckledRect(inner, amp: border * 0.28), Offset.zero);
    } else {
      path.addRRect(
          RRect.fromRectAndRadius(inner, Radius.circular(border * 0.5)));
    }
    canvas.drawPath(path, Paint()..color = const Color(0xF2FFFFFF));
  }

  /// Rectangle whose edges scallop in and out (deckle edge).
  Path _deckledRect(Rect r, {required double amp}) {
    final path = Path()..moveTo(r.left, r.top);
    _wavyLine(path, r.topLeft, r.topRight, amp);
    _wavyLine(path, r.topRight, r.bottomRight, amp);
    _wavyLine(path, r.bottomRight, r.bottomLeft, amp);
    _wavyLine(path, r.bottomLeft, r.topLeft, amp);
    path.close();
    return path;
  }

  void _wavyLine(Path path, Offset from, Offset to, double amp) {
    const wavelength = 26.0;
    final delta = to - from;
    final length = delta.distance;
    final segments = math.max(4, (length / wavelength).round());
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    for (var i = 1; i <= segments; i++) {
      final mid = from + direction * (length * (i - 0.5) / segments);
      final control = mid + normal * (i.isEven ? amp : -amp);
      final end = from + direction * (length * i / segments);
      path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    }
  }

  @override
  bool shouldRepaint(_PrintFramePainter oldDelegate) =>
      oldDelegate.deckle != deckle;
}

/// Warm cardboard mount with an oval window (docs/04 §7, 1845-1890).
class _CardMountPainter extends CustomPainter {
  const _CardMountPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final insetX = size.width * 0.10;
    final insetY = size.height * 0.10;
    final window = Rect.fromLTWH(
      insetX, insetY, size.width - insetX * 2, size.height - insetY * 2);
    final mount = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(window);
    canvas.drawPath(mount, Paint()..color = const Color(0xFFCDBD9C));
    // Slightly darker rim reads as the die-cut edge of the mount.
    canvas.drawOval(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF8A7A5C),
    );
  }

  @override
  bool shouldRepaint(_CardMountPainter oldDelegate) => false;
}

/// Paper margin with the impressed plate rule of a printed engraving.
class _EngravingPlatePainter extends CustomPainter {
  const _EngravingPlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final margin = math.max(14.0, size.shortestSide * 0.055);
    final window = Rect.fromLTWH(
      margin, margin, size.width - margin * 2, size.height - margin * 2);
    final paper = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(window);
    // Paper color matches the shader's engraving paper (docs/03 §3.3).
    canvas.drawPath(paper, Paint()..color = const Color(0xFFEDE0C7));
    canvas.drawRect(
      window.deflate(-margin * 0.25), // the rule sits inside the margin
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF4A3A28),
    );
  }

  @override
  bool shouldRepaint(_EngravingPlatePainter oldDelegate) => false;
}

/// Picture-scroll mounting: bands above/below in portrait, bands plus
/// rollers left/right in landscape (docs/04 §7 — the "peeking at a long
/// scroll" feel).
class _ScrollPainter extends CustomPainter {
  const _ScrollPainter(this.orientation);

  final Orientation orientation;

  static const _band = Color(0xFF2E2A3F); // dark mounting fabric
  static const _gold = Color(0xFFB79A52); // hairline trim
  static const _rod = Color(0xFF1F1B14); // lacquered roller

  @override
  void paint(Canvas canvas, Size size) {
    final bandPaint = Paint()..color = _band;
    final goldPaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (orientation == Orientation.portrait) {
      final band = size.height * 0.08;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, band), bandPaint);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - band, size.width, band), bandPaint);
      canvas.drawLine(Offset(0, band), Offset(size.width, band), goldPaint);
      canvas.drawLine(Offset(0, size.height - band),
          Offset(size.width, size.height - band), goldPaint);
    } else {
      final band = size.width * 0.07;
      final rod = band * 0.45;
      canvas.drawRect(Rect.fromLTWH(0, 0, band, size.height), bandPaint);
      canvas.drawRect(
        Rect.fromLTWH(size.width - band, 0, band, size.height), bandPaint);
      canvas.drawLine(Offset(band, 0), Offset(band, size.height), goldPaint);
      canvas.drawLine(Offset(size.width - band, 0),
          Offset(size.width - band, size.height), goldPaint);
      // Rollers on the outer edges sell the horizontal-scroll reading.
      final rodPaint = Paint()..color = _rod;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, rod, size.height), Radius.circular(rod * 0.5)),
        rodPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - rod, 0, rod, size.height),
          Radius.circular(rod * 0.5)),
        rodPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrollPainter oldDelegate) =>
      oldDelegate.orientation != orientation;
}
