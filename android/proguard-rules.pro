# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

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
