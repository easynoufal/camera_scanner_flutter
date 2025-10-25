package com.carrefour.vision_barcode_scanner

import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

public class VisionBarcodeScannerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        android.util.Log.d("VisionBarcodeScanner", "Plugin onAttachedToEngine called")
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "vision_barcode_scanner")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext

        // Register the platform view factory
        android.util.Log.d("VisionBarcodeScanner", "Registering platform view factory")
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "VisionCameraView",
            VisionCameraViewFactory(flutterPluginBinding.binaryMessenger, context)
        )
        android.util.Log.d("VisionBarcodeScanner", "Platform view factory registered successfully")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            android.util.Log.d("VisionBarcodeScanner", "Plugin registerWith called (legacy)")
            val channel = MethodChannel(registrar.messenger(), "vision_barcode_scanner")
            val instance = VisionBarcodeScannerPlugin()
            channel.setMethodCallHandler(instance)

            // Register the platform view factory
            android.util.Log.d("VisionBarcodeScanner", "Registering platform view factory (legacy)")
            registrar.platformViewRegistry().registerViewFactory(
                "VisionCameraView",
                VisionCameraViewFactory(registrar.messenger(), registrar.context())
            )
            android.util.Log.d("VisionBarcodeScanner", "Platform view factory registered successfully (legacy)")
        }
    }
}

public class VisionCameraViewFactory(
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
    private val context: Context
) : PlatformViewFactory(io.flutter.plugin.common.StandardMessageCodec.INSTANCE) {

    init {
        android.util.Log.d("VisionBarcodeScanner", "VisionCameraViewFactory created")
    }

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        android.util.Log.d("VisionBarcodeScanner", "VisionCameraViewFactory.create called with id: $id")
        return VisionCameraView(context, id, messenger)
    }
}

class VisionCameraView(
    private val context: Context,
    private val viewId: Int,
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) : PlatformView, LifecycleOwner {

    private val previewView: PreviewView = PreviewView(context).apply {
        scaleType = PreviewView.ScaleType.FIT_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val barcodeScanner = BarcodeScanning.getClient()
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val lifecycleRegistry = androidx.lifecycle.LifecycleRegistry(this)

    init {
        android.util.Log.d("VisionBarcodeScanner", "VisionCameraView init - viewId: $viewId")
        setupEventChannel()
        // Initialize lifecycle to CREATED state
        lifecycleRegistry.currentState = androidx.lifecycle.Lifecycle.State.CREATED
        // Delay camera setup to ensure view is ready
        previewView.post {
            android.util.Log.d("VisionBarcodeScanner", "Starting camera setup")
            setupCamera()
        }
    }

    private fun setupEventChannel() {
        eventChannel = EventChannel(messenger, "vision_barcode_scanner/events_$viewId")
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun setupCamera() {
        android.util.Log.d("VisionBarcodeScanner", "setupCamera called")
        
        // Check camera permission
        val hasPermission = ContextCompat.checkSelfPermission(context, android.Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        android.util.Log.d("VisionBarcodeScanner", "Camera permission granted: $hasPermission")
        
        if (!hasPermission) {
            android.util.Log.e("VisionBarcodeScanner", "Camera permission not granted")
            return
        }
        
        // Use the proven approach from your working implementation
        startPreview()
    }
    
    private fun startPreview() {
        android.util.Log.d("VisionBarcodeScanner", "startPreview called")
        
        // ✅ Delay to ensure surface actually exists in scene (from your working code)
        previewView.post {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                try {
                    android.util.Log.d("VisionBarcodeScanner", "Camera provider obtained")
                    cameraProvider = cameraProviderFuture.get()
                    cameraProvider?.unbindAll()

                    val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                    val preview = Preview.Builder().build()
                    
                    // Set optimal resolution like in your working code
                    val resolution = getOptimalResolution()
                    imageAnalyzer = ImageAnalysis.Builder()
                        .setTargetResolution(resolution)
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also {
                            it.setAnalyzer(cameraExecutor, BarcodeAnalyzer { barcode ->
                                android.util.Log.d("VisionBarcodeScanner", "Barcode detected: $barcode")
                                eventSink?.success(barcode)
                            })
                        }

                    camera = cameraProvider?.bindToLifecycle(
                        this,
                        cameraSelector,
                        imageAnalyzer,
                        preview
                    )
                    preview.setSurfaceProvider(previewView.surfaceProvider)

                    // Move lifecycle to STARTED state when camera is ready
                    lifecycleRegistry.currentState = androidx.lifecycle.Lifecycle.State.STARTED
                    android.util.Log.d("VisionBarcodeScanner", "Camera preview started successfully")

                } catch (e: Exception) {
                    android.util.Log.e("VisionBarcodeScanner", "Error starting preview", e)
                    e.printStackTrace()
                }
            }, ContextCompat.getMainExecutor(context))
        }
    }
    
    private fun getOptimalResolution(): android.util.Size {
        return if (previewView.display?.rotation == android.view.Surface.ROTATION_0) {
            android.util.Size(720, 1280)
        } else {
            android.util.Size(1280, 720)
        }
    }


    override fun getView(): android.view.View {
        android.util.Log.d("VisionBarcodeScanner", "getView called - returning PreviewView")
        android.util.Log.d("VisionBarcodeScanner", "PreviewView dimensions: ${previewView.width}x${previewView.height}")
        android.util.Log.d("VisionBarcodeScanner", "PreviewView visibility: ${previewView.visibility}")
        return previewView
    }

    override fun dispose() {
        lifecycleRegistry.currentState = androidx.lifecycle.Lifecycle.State.DESTROYED
        cameraProvider?.unbindAll()
        cameraExecutor.shutdown()
        barcodeScanner.close()
    }

    override val lifecycle: androidx.lifecycle.Lifecycle
        get() = lifecycleRegistry
}

class BarcodeAnalyzer(private val onBarcodeDetected: (String) -> Unit) : ImageAnalysis.Analyzer {
    private val barcodeScanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            .build()
    )

    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            
            barcodeScanner.process(image)
                .addOnSuccessListener { barcodes ->
                    barcodes.firstOrNull()?.let { barcode ->
                        barcode.rawValue?.let { value ->
                            android.util.Log.d("VisionBarcodeScanner", "Barcode detected: $value")
                            onBarcodeDetected(value)
                        }
                    }
                }
                .addOnFailureListener { exception ->
                    android.util.Log.e("VisionBarcodeScanner", "Barcode scanning error: ${exception.message}", exception)
                }
                .addOnCompleteListener {
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }
}
