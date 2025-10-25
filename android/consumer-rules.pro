# Consumer ProGuard rules for vision_barcode_scanner
# These rules will be applied to projects that use this library

# Keep all classes in the vision_barcode_scanner package
-keep class com.carrefour.vision_barcode_scanner.** { *; }

# Keep Flutter plugin classes
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }

# Keep CameraX classes
-keep class androidx.camera.** { *; }

# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }

# Keep lifecycle classes
-keep class androidx.lifecycle.** { *; }
