package com.daisuke7.historical.camera

import com.daisuke7.historical.camera.historicalcamera.HistoricalCameraPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // In-app plugin, registered manually (docs/06 §2).
        flutterEngine.plugins.add(HistoricalCameraPlugin())
    }
}
