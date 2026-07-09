import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/era_scale.dart';
import '../strings.dart';

/// Custom non-linear era slider (docs/04 §2).
///
/// The track maps position to year through [yearForPosition] (piecewise
/// linear, dense on the recent century). While dragging, the continuous year
/// is reported through [onChanged]; on release [onChangeEnd] fires once with
/// the decade-quantized year and the thumb snaps to it over 150 ms, still
/// reporting intermediate values through [onChanged] so the filter follows
/// smoothly.
class EraSlider extends StatefulWidget {
  const EraSlider({
    super.key,
    required this.year,
    required this.nowYear,
    required this.onChanged,
    required this.onChangeEnd,
  });

  /// Current (continuous) year when the user is not interacting.
  final double year;
  final int nowYear;
  final ValueChanged<double> onChanged;
  final ValueChanged<int> onChangeEnd;

  /// Total widget height, including tick labels.
  static const height = 72.0;

  /// Horizontal inset of the track inside the widget.
  static const trackPadding = 24.0;

  @override
  State<EraSlider> createState() => _EraSliderState();
}

class _EraSliderState extends State<EraSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  Animation<double>? _snapAnimation;

  /// Non-null while the user drags or the snap animation runs.
  double? _localYear;
  double? _lastHapticYear;

  double get _displayYear => _localYear ?? widget.year;

  @override
  void initState() {
    super.initState();
    _snap.addListener(_onSnapTick);
    _snap.addStatusListener(_onSnapStatus);
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    final animation = _snapAnimation;
    if (animation == null) return;
    setState(() => _localYear = animation.value);
    widget.onChanged(animation.value);
  }

  void _onSnapStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _localYear = null);
    }
  }

  void _handlePointer(double dx, double width) {
    _snap.stop();
    final p =
        (dx - EraSlider.trackPadding) / (width - 2 * EraSlider.trackPadding);
    final year = yearForPosition(p, widget.nowYear);
    _fireHaptics(year);
    setState(() => _localYear = year);
    widget.onChanged(year);
  }

  void _handleRelease() {
    final quantized =
        math.min(widget.nowYear, (_displayYear / 10).round() * 10);
    // onChangeEnd fires at finger-up, not at snap completion (docs/04 §2.2).
    widget.onChangeEnd(quantized);
    _snapAnimation = Tween<double>(
      begin: _displayYear,
      end: quantized.toDouble(),
    ).animate(CurvedAnimation(parent: _snap, curve: Curves.easeOut));
    _snap.forward(from: 0);
  }

  /// Haptic density follows the density of visual change per era band, with
  /// a stronger impact on the media boundaries (docs/04 §2.2).
  void _fireHaptics(double year) {
    final last = _lastHapticYear;
    _lastHapticYear = year;
    if (last == null || last == year) return;

    for (final boundary in const [1839.0, 1500.0]) {
      if ((last - boundary).sign != (year - boundary).sign) {
        HapticFeedback.mediumImpact();
        return;
      }
    }

    final double step;
    if (year >= widget.nowYear - 100) {
      step = 10;
    } else if (year >= 1500) {
      step = 50;
    } else {
      step = 100;
    }
    if ((last / step).floor() != (year / step).floor()) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragDown: (d) => _handlePointer(d.localPosition.dx, width),
        onHorizontalDragUpdate: (d) =>
            _handlePointer(d.localPosition.dx, width),
        onHorizontalDragEnd: (_) => _handleRelease(),
        onHorizontalDragCancel: _handleRelease,
        onTapUp: (d) {
          _handlePointer(d.localPosition.dx, width);
          _handleRelease();
        },
        child: CustomPaint(
          size: Size(width, EraSlider.height),
          painter: _EraSliderPainter(
            year: _displayYear,
            nowYear: widget.nowYear,
          ),
        ),
      );
    });
  }
}

class _EraSliderPainter extends CustomPainter {
  _EraSliderPainter({required this.year, required this.nowYear});

  final double year;
  final int nowYear;

  static const _trackY = 34.0;

  double _xForYear(double y, Size size) {
    final usable = size.width - 2 * EraSlider.trackPadding;
    return EraSlider.trackPadding + positionForYear(y, nowYear) * usable;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = Colors.white30
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(EraSlider.trackPadding, _trackY),
      Offset(size.width - EraSlider.trackPadding, _trackY),
      track,
    );

    // Century ticks (docs/04 §2.2).
    final tick = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var y = 1000; y <= nowYear; y += 100) {
      final x = _xForYear(y.toDouble(), size);
      canvas.drawLine(Offset(x, _trackY - 4), Offset(x, _trackY + 4), tick);
    }

    // Anchor labels: 1000 / 1500 / 1900 / now.
    for (final (labelYear, text) in [
      (1000.0, '1000'),
      (1500.0, '1500'),
      (1900.0, '1900'),
      (nowYear.toDouble(), Strings.now),
    ]) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // The upper bound can go below 0 mid-rotation when the slider is
      // momentarily narrower than the label; clamp would throw then.
      final x = math.max(
          0.0,
          math.min(_xForYear(labelYear, size) - painter.width / 2,
              size.width - painter.width));
      painter.paint(canvas, Offset(x, _trackY + 10));
    }

    // Thumb.
    final thumbX = _xForYear(year.clamp(1000.0, nowYear.toDouble()), size);
    canvas.drawCircle(
      Offset(thumbX, _trackY),
      10,
      Paint()..color = Colors.black38,
    );
    canvas.drawCircle(
      Offset(thumbX, _trackY),
      9,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_EraSliderPainter oldDelegate) =>
      oldDelegate.year != year || oldDelegate.nowYear != nowYear;
}
