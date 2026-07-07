import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/era_filter.dart';
import '../domain/filter_params.dart';
import '../platform/camera_event.dart';
import '../platform/native_camera_api.dart';
import '../state/camera_state.dart';
import '../strings.dart';

part 'debug_panel.freezed.dart';

/// Hidden tuning panel (docs/04 §8). Ships in release builds too; the only
/// entry point is the 3-second long-press on the era label (docs/08 §8.3).

/// GPU budget threshold; readings above it render red (docs/04 §8.2).
const double kGpuBudgetMs = 8.0;

/// State of the debug panel (docs/04 §8.2).
@freezed
abstract class DebugPanelState with _$DebugPanelState {
  const factory DebugPanelState({
    /// Whether the panel overlay is on screen.
    required bool visible,

    /// Manual mode: panel sliders drive the filter instead of the era year.
    /// Survives closing the panel (the 手動 badge marks it).
    required bool manual,

    /// Values driven by the sliders while [manual] is true.
    required FilterParams manualParams,

    /// Explicit resolution selection (docs/04 §8.2 verification toggle).
    required String resolutionPreset,

    /// Latest `debugStats` reading; null until the first event arrives.
    double? gpuMs,
  }) = _DebugPanelState;
}

final debugPanelProvider =
    NotifierProvider<DebugPanelController, DebugPanelState>(
        DebugPanelController.new);

/// Owns the docs/04 §8 behavior. Manual values go to the native side through
/// the same [NativeCameraApi.setFilterParams] path as the era slider, so the
/// 16 ms throttling applies unchanged.
class DebugPanelController extends Notifier<DebugPanelState> {
  StreamSubscription<CameraEvent>? _statsSub;

  @override
  DebugPanelState build() {
    ref.onDispose(() {
      _statsSub?.cancel();
      _statsSub = null;
    });
    // Moving the era slider while in manual mode re-seeds the manual values
    // from that year (docs/04 §8.2: start near a year, then fine-tune).
    ref.listen(cameraNotifierProvider.select((s) => s.year), (previous, next) {
      if (previous == null || previous == next) return;
      if (state.manual) {
        state = state.copyWith(manualParams: _paramsForCurrentYear());
      }
    });
    return const DebugPanelState(
      visible: false,
      manual: false,
      manualParams: FilterParams.neutral,
      resolutionPreset: 'auto',
    );
  }

  NativeCameraApi get _api => ref.read(nativeCameraApiProvider);

  FilterParams _paramsForCurrentYear() {
    final camera = ref.read(cameraNotifierProvider);
    return paramsForYear(camera.year, camera.nowYear);
  }

  void open() {
    if (state.visible) return;
    state = state.copyWith(visible: true);
    _statsSub ??= _api.events.listen((event) {
      if (event is DebugStatsEvent) {
        state = state.copyWith(gpuMs: event.gpuMs);
      }
    });
    unawaited(_setStatsEnabled(true));
  }

  /// Closes the panel. Manual mode is kept on purpose (docs/04 §8.2): the
  /// badge lets the user shoot and compare, then come back.
  void close() {
    if (!state.visible) return;
    state = state.copyWith(visible: false);
    unawaited(_setStatsEnabled(false));
  }

  void setManual(bool manual) {
    if (manual == state.manual) return;
    if (manual) {
      // Manual starts from the current year's values (docs/04 §8.2).
      state = state.copyWith(
        manual: true,
        manualParams: _paramsForCurrentYear(),
      );
    } else {
      state = state.copyWith(manual: false);
      // Back to year-linked: restore the era look right away.
      unawaited(_api.setFilterParams(_paramsForCurrentYear()));
    }
  }

  /// Manual slider edit.
  void updateManualParams(FilterParams params) {
    if (!state.manual) return;
    state = state.copyWith(manualParams: params);
    unawaited(_api.setFilterParams(params));
  }

  /// The 20 values the panel currently shows (= what JSON copy exports).
  FilterParams effectiveParams() =>
      state.manual ? state.manualParams : _paramsForCurrentYear();

  /// Copies the current values as JSON keyed by the docs/02 §2 field names,
  /// for transcription into the docs/03 §2.1 keyframe table.
  Future<void> copyJson() {
    final json =
        const JsonEncoder.withIndent('  ').convert(effectiveParams().toMap());
    return Clipboard.setData(ClipboardData(text: json));
  }

  /// Explicit resolution selection; re-initializes the native session
  /// (docs/04 §8.2). "auto" resolves from the persisted 1080p gate result
  /// on the native side (docs/01 §1.1).
  Future<void> setResolutionPreset(String preset) async {
    if (preset == state.resolutionPreset) return;
    state = state.copyWith(resolutionPreset: preset);
    await ref
        .read(cameraNotifierProvider.notifier)
        .reinitializeWithPreset(preset);
    // Re-initialize reset the native stats flag and params; restore them.
    if (state.visible) unawaited(_setStatsEnabled(true));
    if (state.manual) unawaited(_api.setFilterParams(state.manualParams));
  }

  Future<void> _setStatsEnabled(bool enabled) async {
    try {
      await _api.setDebugStatsEnabled(enabled);
    } on PlatformException {
      // Stats are best-effort; the panel works without the GPU readout.
    } on MissingPluginException {
      // Native side absent (tests / unsupported platform).
    }
  }
}

/// Entry point: wraps the era label and opens the panel after a 3-second
/// long-press (docs/04 §8.1). Only this wrapper and [DebugPanelHost] touch
/// CameraScreen (docs/04 §8.3).
class DebugPanelTrigger extends ConsumerStatefulWidget {
  const DebugPanelTrigger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DebugPanelTrigger> createState() => _DebugPanelTriggerState();
}

class _DebugPanelTriggerState extends ConsumerState<DebugPanelTrigger> {
  Timer? _holdTimer;

  // Long-press fires after kLongPressTimeout (500 ms); the remainder makes
  // the total hold ~3 s (docs/04 §8.1).
  static const _remainingHold = Duration(milliseconds: 2500);

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) {
        _holdTimer = Timer(_remainingHold, () {
          ref.read(debugPanelProvider.notifier).open();
        });
      },
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      // Padding keeps the hidden hit target usable while the label itself
      // is faded out.
      child: Padding(padding: const EdgeInsets.all(12), child: widget.child),
    );
  }
}

/// Stack layer for CameraScreen: shows the panel when open, or the small
/// 手動 badge when manual mode survives a close (docs/04 §8.2).
class DebugPanelHost extends ConsumerWidget {
  const DebugPanelHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (visible, manual) = ref.watch(
      debugPanelProvider.select((s) => (s.visible, s.manual)),
    );
    if (visible) return const _DebugPanel();
    if (manual) return const _ManualBadge();
    return const SizedBox.shrink();
  }
}

/// Tap returns to year-linked mode.
class _ManualBadge extends ConsumerWidget {
  const _ManualBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 16),
          child: GestureDetector(
            key: const Key('debug_manual_badge'),
            onTap: () =>
                ref.read(debugPanelProvider.notifier).setManual(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                Strings.debugManualBadge,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One slider row per FilterParams field, in the docs/02 §2 declaration
/// order and value ranges.
class _ParamSpec {
  const _ParamSpec(this.name, this.min, this.max, this.get, this.apply);

  final String name;
  final double min;
  final double max;
  final double Function(FilterParams) get;
  final FilterParams Function(FilterParams, double) apply;
}

final List<_ParamSpec> _paramSpecs = [
  _ParamSpec('monochrome', 0, 1, (p) => p.monochrome,
      (p, v) => p.copyWith(monochrome: v)),
  _ParamSpec('sepia', 0, 1, (p) => p.sepia, (p, v) => p.copyWith(sepia: v)),
  _ParamSpec('saturation', 0, 2, (p) => p.saturation,
      (p, v) => p.copyWith(saturation: v)),
  _ParamSpec('contrast', 0.5, 1.5, (p) => p.contrast,
      (p, v) => p.copyWith(contrast: v)),
  _ParamSpec('brightness', -0.3, 0.3, (p) => p.brightness,
      (p, v) => p.copyWith(brightness: v)),
  _ParamSpec('warmth', -1, 1, (p) => p.warmth,
      (p, v) => p.copyWith(warmth: v)),
  _ParamSpec('fade', 0, 1, (p) => p.fade, (p, v) => p.copyWith(fade: v)),
  _ParamSpec('grain', 0, 1, (p) => p.grain, (p, v) => p.copyWith(grain: v)),
  _ParamSpec('grainSize', 1, 4, (p) => p.grainSize,
      (p, v) => p.copyWith(grainSize: v)),
  _ParamSpec('vignette', 0, 1, (p) => p.vignette,
      (p, v) => p.copyWith(vignette: v)),
  _ParamSpec('scratches', 0, 1, (p) => p.scratches,
      (p, v) => p.copyWith(scratches: v)),
  _ParamSpec('dust', 0, 1, (p) => p.dust, (p, v) => p.copyWith(dust: v)),
  _ParamSpec('jitter', 0, 1, (p) => p.jitter,
      (p, v) => p.copyWith(jitter: v)),
  _ParamSpec('halation', 0, 1, (p) => p.halation,
      (p, v) => p.copyWith(halation: v)),
  _ParamSpec('blur', 0, 1, (p) => p.blur, (p, v) => p.copyWith(blur: v)),
  _ParamSpec('orthochromatic', 0, 1, (p) => p.orthochromatic,
      (p, v) => p.copyWith(orthochromatic: v)),
  _ParamSpec('engraving', 0, 1, (p) => p.engraving,
      (p, v) => p.copyWith(engraving: v)),
  _ParamSpec('hatchScale', 0.5, 1, (p) => p.hatchScale,
      (p, v) => p.copyWith(hatchScale: v)),
  _ParamSpec('inkPainting', 0, 1, (p) => p.inkPainting,
      (p, v) => p.copyWith(inkPainting: v)),
  _ParamSpec('paperTexture', 0, 1, (p) => p.paperTexture,
      (p, v) => p.copyWith(paperTexture: v)),
];

/// Full-screen translucent dark panel (docs/04 §8.2). The preview keeps
/// running behind it.
class _DebugPanel extends ConsumerWidget {
  const _DebugPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debug = ref.watch(debugPanelProvider);
    final (year, nowYear) = ref.watch(
      cameraNotifierProvider.select((s) => (s.year, s.nowYear)),
    );
    final params =
        debug.manual ? debug.manualParams : paramsForYear(year, nowYear);
    final notifier = ref.read(debugPanelProvider.notifier);

    return ColoredBox(
      key: const Key('debug_panel'),
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Column(
          children: [
            _Header(debug: debug, notifier: notifier),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _paramSpecs.length,
                itemBuilder: (context, index) => _ParamRow(
                  spec: _paramSpecs[index],
                  params: params,
                  enabled: debug.manual,
                  onChanged: (updated) => notifier.updateManualParams(updated),
                ),
              ),
            ),
            _Footer(debug: debug, notifier: notifier),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.debug, required this.notifier});

  final DebugPanelState debug;
  final DebugPanelController notifier;

  @override
  Widget build(BuildContext context) {
    final gpuMs = debug.gpuMs;
    final overBudget = gpuMs != null && gpuMs > kGpuBudgetMs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SegmentedButton<bool>(
            key: const Key('debug_mode_toggle'),
            segments: const [
              ButtonSegment(
                value: false,
                label: Text(Strings.debugModeLinked,
                    style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: true,
                label: Text(Strings.debugModeManual,
                    style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {debug.manual},
            onSelectionChanged: (selection) =>
                notifier.setManual(selection.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Spacer(),
          Text(
            gpuMs == null
                ? Strings.debugGpuPlaceholder
                : Strings.debugGpu(gpuMs),
            key: const Key('debug_gpu_readout'),
            style: TextStyle(
              // Over-budget frames turn red (docs/04 §8.2).
              color: overBudget ? Colors.redAccent : Colors.white70,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            key: const Key('debug_close_button'),
            onPressed: notifier.close,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({
    required this.spec,
    required this.params,
    required this.enabled,
    required this.onChanged,
  });

  final _ParamSpec spec;
  final FilterParams params;
  final bool enabled;
  final ValueChanged<FilterParams> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = spec.get(params).clamp(spec.min, spec.max).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            spec.name,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: spec.min,
              max: spec.max,
              onChanged:
                  enabled ? (v) => onChanged(spec.apply(params, v)) : null,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.debug, required this.notifier});

  final DebugPanelState debug;
  final DebugPanelController notifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          TextButton.icon(
            key: const Key('debug_copy_json'),
            onPressed: () async {
              await notifier.copyJson();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(Strings.debugJsonCopied)),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
            label: const Text(
              Strings.debugCopyJson,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const Spacer(),
          const Text(
            Strings.debugResolutionLabel,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 6),
          DropdownButton<String>(
            key: const Key('debug_resolution_dropdown'),
            value: debug.resolutionPreset,
            dropdownColor: const Color(0xFF303030),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('auto')),
              DropdownMenuItem(value: 'hd720', child: Text('hd720')),
              DropdownMenuItem(value: 'hd1080', child: Text('hd1080')),
            ],
            onChanged: (preset) {
              if (preset != null) notifier.setResolutionPreset(preset);
            },
          ),
          const SizedBox(width: 12),
          // Regional engraving preset (docs/03 §5); enabled once T20 lands.
          Tooltip(
            message: Strings.debugRegionPending,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  Strings.debugRegionLabel,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                SizedBox(width: 4),
                Text(
                  '${Strings.debugRegionJapanese}/${Strings.debugRegionWestern}',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
