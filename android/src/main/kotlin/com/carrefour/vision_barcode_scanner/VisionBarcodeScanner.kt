package com.carrefour.vision_barcode_scanner

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger

/**
 * Main entry point for the VisionBarcodeScanner plugin
 * This class provides a simple API for native Android projects to use the plugin
 */
public class VisionBarcodeScanner {
    
    companion object {
        /**
         * Register the VisionBarcodeScanner plugin with a FlutterEngine
         * Call this method in your native Android project after creating the FlutterEngine
         * 
         * @param flutterEngine The FlutterEngine instance
         */
        @JvmStatic
        public fun registerWith(flutterEngine: FlutterEngine) {
            val plugin = VisionBarcodeScannerPlugin()
            flutterEngine.plugins.add(plugin)
            android.util.Log.d("VisionBarcodeScanner", "Plugin registered with FlutterEngine")
        }
        
        /**
         * Create a plugin instance for manual registration
         * 
         * @return VisionBarcodeScannerPlugin instance
         */
        @JvmStatic
        public fun createPlugin(): VisionBarcodeScannerPlugin {
            return VisionBarcodeScannerPlugin()
        }
        
        /**
         * Create a platform view factory for manual registration
         * 
         * @param messenger BinaryMessenger instance
         * @param context Android Context
         * @return VisionCameraViewFactory instance
         */
        @JvmStatic
        public fun createViewFactory(
            messenger: BinaryMessenger,
            context: Context
        ): VisionCameraViewFactory {
            return VisionCameraViewFactory(messenger, context)
        }
    }
}
