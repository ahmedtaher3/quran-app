package com.tarik.al.quran

import android.content.Intent
import android.hardware.GeomagneticField
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity: required by just_audio_background for lock-screen controls
class MainActivity : AudioServiceActivity() {
    private var adhanSound: AdhanSoundChannel? = null

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (adhanSound?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        adhanSound?.dispose()
        adhanSound = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        adhanSound?.dispose()
        adhanSound = AdhanSoundChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tarik/prayer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Compass headings on Android are magnetic; qibla is from
                    // true north. World Magnetic Model value, east positive.
                    "declination" -> {
                        val lat = call.argument<Double>("lat")
                        val lng = call.argument<Double>("lng")
                        if (lat == null || lng == null) {
                            result.error("args", "lat and lng are required", null)
                        } else {
                            val field = GeomagneticField(
                                lat.toFloat(), lng.toFloat(), 0f, System.currentTimeMillis()
                            )
                            result.success(field.declination.toDouble())
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
