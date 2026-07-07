import Foundation

/// One-time on-device 1080p unlock gate (docs/01 §1.1).
///
/// Renders 30 frames of the worst-case ink-era parameters into an offscreen
/// 1920x1080 target through `FilterBenchmark` (shared with the RunnerTests
/// budget test) and persists `p90 < 8ms` keyed by the app version, so a
/// shader-changing update re-measures automatically. `resolutionPreset:
/// "auto"` resolves against the persisted result; the unlock therefore takes
/// effect from the NEXT initialize (docs/02 §3.1).
enum ResolutionGate {
    static let budgetMs = 8.0

    /// Idle delay after preview start; the bench must never block the first
    /// launch (docs/01 §1.1).
    private static let idleDelay: TimeInterval = 3.0

    private static var scheduled = false

    /// Worst-case ink-era parameters (~paramsForYear(1100), the heaviest era
    /// measured in P0 — docs/01 §1.1). Same set as the RunnerTests GPU test
    /// and the Android FilterGpuBudgetTest.
    static var inkEraWorstCase: FilterParams {
        var params = FilterParams.neutral
        params.monochrome = 1.0
        params.sepia = 0.4
        params.fade = 0.68
        params.grain = 0.05
        params.grainSize = 2.0
        params.vignette = 0.45
        params.dust = 0.5
        params.blur = 0.34
        params.orthochromatic = 1.0
        params.inkPainting = 1.0
        params.paperTexture = 1.0
        return params
    }

    static var storageKey: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "HistoricalCamera.hd1080Gate.\(version)-\(build)"
    }

    /// Persisted gate result for this app version; nil = not measured yet.
    static func storedResult(defaults: UserDefaults = .standard) -> Bool? {
        defaults.object(forKey: storageKey) as? Bool
    }

    /// Resolves `"auto"` to hd720/hd1080; an absent result means hd720.
    static func resolvePreset(
        _ preset: String, defaults: UserDefaults = .standard
    ) -> String {
        guard preset == "auto" else { return preset }
        return storedResult(defaults: defaults) == true ? "hd1080" : "hd720"
    }

    /// Runs the bench once per install-version, on a background queue
    /// shortly after preview start. No-op when already measured.
    static func scheduleIfNeeded() {
        guard !scheduled, storedResult() == nil else { return }
        scheduled = true
        DispatchQueue.global(qos: .utility)
            .asyncAfter(deadline: .now() + idleDelay) {
                runAndStore()
            }
    }

    static func runAndStore(defaults: UserDefaults = .standard) {
        guard let times = FilterBenchmark.run(
            width: 1920, height: 1080, params: inkEraWorstCase)
        else {
            // Metal unavailable: leave the result unset so a later launch
            // can retry (720p stays in effect meanwhile).
            scheduled = false
            return
        }
        let p90 = FilterBenchmark.percentileMs(times, 90)
        let pass = p90 < budgetMs
        defaults.set(pass, forKey: storageKey)
        NSLog("1080p gate: p90 %.2f ms -> %@", p90,
              pass ? "unlocked" : "locked")
    }
}
