package com.versreminder.vers_reminder

import android.app.WallpaperManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "vers_reminder/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "suggestDesiredDimensions" -> {
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    if (width <= 0 || height <= 0) {
                        result.error("INVALID_ARG", "Width and height must be > 0", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val wallpaperManager = WallpaperManager.getInstance(this)
                        // Suggest dimensions so Android doesn't rescale the image.
                        // Deprecated from API 32+ but still honored on most devices,
                        // and harmless to call.
                        wallpaperManager.suggestDesiredDimensions(width, height)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLATFORM_ERROR", "Failed to suggest dimensions: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
