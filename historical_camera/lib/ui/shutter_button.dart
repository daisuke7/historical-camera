import 'package:flutter/material.dart';

/// 72 dp round shutter button (docs/04 §4). Dumb component: enablement and
/// the capture action are owned by the caller. While disabled (a capture is
/// in flight) it dims to 40% opacity and ignores taps.
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  static const diameter = 72.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          alignment: Alignment.center,
          child: Container(
            width: diameter - 16,
            height: diameter - 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
