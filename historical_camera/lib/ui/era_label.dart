import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/camera_state.dart';
import '../strings.dart';

/// Big year readout at the top center (docs/04 §3).
///
/// Visible while the slider moves and for 1.5 s afterwards, then fades out
/// over 300 ms. Crossing a media boundary (1839, 1500) temporarily replaces
/// the subtitle with a callout such as "1839 写真の発明".
class EraLabel extends ConsumerStatefulWidget {
  const EraLabel({super.key});

  static const visibleDuration = Duration(milliseconds: 1500);
  static const fadeDuration = Duration(milliseconds: 300);

  @override
  ConsumerState<EraLabel> createState() => _EraLabelState();
}

class _EraLabelState extends ConsumerState<EraLabel> {
  Timer? _hideTimer;
  bool _visible = false;
  String? _boundaryText;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onYearChanged(double? previous, double next) {
    if (previous == null || previous == next) return;
    for (final (boundary, text) in const [
      (1839.0, Strings.boundaryPhotography),
      (1500.0, Strings.boundaryEngraving),
    ]) {
      if ((previous - boundary).sign != (next - boundary).sign) {
        _boundaryText = text;
      }
    }
    setState(() => _visible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(EraLabel.visibleDuration, () {
      if (!mounted) return;
      setState(() {
        _visible = false;
        _boundaryText = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      cameraNotifierProvider.select((s) => s.year),
      _onYearChanged,
    );
    final (quantizedYear, nowYear) = ref.watch(
      cameraNotifierProvider.select((s) => (s.quantizedYear, s.nowYear)),
    );

    final subtitle =
        _boundaryText ?? Strings.eraDescription(quantizedYear, nowYear);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: EraLabel.fadeDuration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Strings.eraTitle(quantizedYear, nowYear),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
