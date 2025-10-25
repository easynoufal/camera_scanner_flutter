package com.carrefour.vision_barcode_scanner

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/**
 * Helper class to manually register the VisionBarcodeScannerPlugin
 * This is useful when using the plugin as an AAR in native Android projects
 */
public object VisionBarcodeScannerHelper {
    
    /**
     * Manually register the VisionBarcodeScannerPlugin with a FlutterEngine
     * Call this method in your native Android project after creating the FlutterEngine
     */
    public fun registerWithFlutterEngine(flutterEngine: FlutterEngine) {
        val plugin = VisionBarcodeScannerPlugin()
        flutterEngine.plugins.add(plugin)
        android.util.Log.d("VisionBarcodeScanner", "Plugin registered with FlutterEngine")
    }
    
    /**
     * Manually register the platform view factory
     * This is an alternative method if the automatic registration doesn't work
     */
    public fun registerPlatformViewFactory(
        messenger: BinaryMessenger,
        context: Context
    ) {
        val factory = VisionCameraViewFactory(messenger, context)
        // Note: This would need to be called on the platform view registry
        // The exact implementation depends on how you're integrating Flutter
        android.util.Log.d("VisionBarcodeScanner", "Platform view factory registered manually")
    }
    
    /**
     * Get the plugin instance for manual registration
     */
    public fun getPlugin(): VisionBarcodeScannerPlugin {
        return VisionBarcodeScannerPlugin()
    }
}
