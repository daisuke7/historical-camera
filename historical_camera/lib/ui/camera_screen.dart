import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/camera_state.dart';
import '../strings.dart';
import 'debug_panel.dart';
import 'era_label.dart';
import 'era_slider.dart';
import 'shutter_button.dart';

/// The single screen of the app (docs/04).
///
/// Rebuild policy (docs/02 §1 principle 3): this widget watches only `phase`;
/// the preview texture subtree watches only texture-related fields. Slider
/// drags rebuild the slider and the era label, never the preview.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    value: 1.0, // resting position = fully faded out
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraNotifierProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flash.dispose();
    super.dispose();
  }

  /// Background/foreground drives pausePreview/resumePreview
  /// (docs/02 §1 principle 4).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(cameraNotifierProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
        notifier.pause();
      case AppLifecycleState.resumed:
        notifier.resume();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // White flash when a capture completes (docs/04 §4).
    ref.listen(cameraNotifierProvider.select((s) => s.lastSavedPath),
        (previous, next) {
      if (next != null && next != previous) {
        _flash.forward(from: 0);
      }
    });

    // Screen stays awake while the camera is live (docs/04 §6).
    ref.listen(cameraNotifierProvider.select((s) => s.phase),
        (previous, next) {
      const active = {
        CameraPhase.previewing,
        CameraPhase.capturing,
        CameraPhase.recording,
      };
      ref.read(wakelockServiceProvider).setEnabled(active.contains(next));
    });

    // Transient runtime errors surface as a SnackBar; the fatal path has its
    // own full-screen view (docs/08 T11).
    ref.listen(cameraNotifierProvider.select((s) => s.errorMessage),
        (previous, next) {
      if (next == null || next == previous) return;
      if (ref.read(cameraNotifierProvider).phase == CameraPhase.error) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(next)));
    });

    final phase =
        ref.watch(cameraNotifierProvider.select((s) => s.phase));

    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (phase) {
        CameraPhase.permissionDenied => const _PermissionDeniedView(),
        CameraPhase.error => const _ErrorView(),
        _ => Stack(
            fit: StackFit.expand,
            children: [
              const _PreviewLayer(),
              const _CameraOverlay(),
              // Hidden tuning panel / manual badge (docs/04 §8).
              const DebugPanelHost(),
              _FlashOverlay(animation: _flash),
            ],
          ),
      },
    );
  }
}

/// Fullscreen preview. Watches only texture-related fields so slider drags
/// never rebuild it. Shows the boot spinner while the texture is not ready.
class _PreviewLayer extends ConsumerWidget {
  const _PreviewLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (textureId, width, height, quarterTurns) = ref.watch(
      cameraNotifierProvider.select(
        (s) => (s.textureId, s.previewWidth, s.previewHeight, s.quarterTurns),
      ),
    );

    if (textureId == null || width == null || height == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white24),
        ),
      );
    }

    // Sensor-oriented buffer rotated for display (docs/02 §4.1), covering the
    // screen; overflow is clipped (docs/04 §1.3).
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: SizedBox(
            width: width.toDouble(),
            height: height.toDouble(),
            child: Texture(textureId: textureId),
          ),
        ),
      ),
    );
  }
}

/// All overlay UI. The bottom = slider / right = shutter relationship holds
/// in both orientations (docs/04 §1.1-1.2).
class _CameraOverlay extends StatelessWidget {
  const _CameraOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Legibility gradient behind the slider band (docs/04 §1.3).
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: Container(
                height: EraSlider.height + 24,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black38],
                  ),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 16),
              // 3-second long-press opens the debug panel (docs/04 §8.1).
              child: DebugPanelTrigger(child: EraLabel()),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: _ShutterArea(),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _EraSliderBar(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterArea extends ConsumerWidget {
  const _ShutterArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase =
        ref.watch(cameraNotifierProvider.select((s) => s.phase));
    return ShutterButton(
      key: const Key('shutter_button'),
      enabled: phase == CameraPhase.previewing,
      onPressed: () =>
          ref.read(cameraNotifierProvider.notifier).capturePhoto(),
    );
    // Video mode stays hidden until P2 (docs/04 §4), so there is no mode
    // segment in P0.
  }
}

class _EraSliderBar extends ConsumerWidget {
  const _EraSliderBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (year, nowYear) = ref.watch(
      cameraNotifierProvider.select((s) => (s.year, s.nowYear)),
    );
    final notifier = ref.read(cameraNotifierProvider.notifier);
    return EraSlider(
      year: year,
      nowYear: nowYear,
      onChanged: notifier.onYearChanged,
      onChangeEnd: notifier.onYearChangeEnd,
    );
  }
}

class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: animation.drive(Tween(begin: 1.0, end: 0.0)),
        child: const ColoredBox(color: Colors.white),
      ),
    );
  }
}

class _PermissionDeniedView extends ConsumerWidget {
  const _PermissionDeniedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cameraNotifierProvider.notifier);
    return _MessageView(
      title: Strings.permissionDeniedTitle,
      body: Strings.permissionDeniedBody,
      actions: [
        FilledButton(
          onPressed: notifier.openAppSettings,
          child: const Text(Strings.openSettings),
        ),
        TextButton(
          onPressed: notifier.initialize,
          child: const Text(Strings.retry),
        ),
      ],
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(
      cameraNotifierProvider.select((s) => s.errorMessage),
    );
    return _MessageView(
      title: Strings.errorTitle,
      body: message ?? '',
      actions: [
        FilledButton(
          onPressed: ref.read(cameraNotifierProvider.notifier).initialize,
          child: const Text(Strings.retry),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}
