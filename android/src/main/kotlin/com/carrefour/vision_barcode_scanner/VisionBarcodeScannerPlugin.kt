package com.carrefour.vision_barcode_scanner

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.view.ViewGroup
import androidx.camera.core.*
import androidx.camera.core.Camera
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
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
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
        val argsMap = args as? Map<*, *>
        val formats = argsMap?.get("formats") as? List<*>
        return VisionCameraView(context, id, messenger, formats)
    }
}

class VisionCameraView(
    private val context: Context,
    private val viewId: Int,
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
    private val formats: List<*>?
) : PlatformView, LifecycleOwner {

    private val previewView: PreviewView = PreviewView(context).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val barcodeScanner = BarcodeScanning.getClient(getBarcodeScannerOptions(formats))
    private var eventChannel: EventChannel? = null
    private var methodChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val lifecycleRegistry = androidx.lifecycle.LifecycleRegistry(this)
    private var isScanning = true
    private var lastImageProxy: ImageProxy? = null
    private var isTorchOn = false
    
    private fun getBarcodeScannerOptions(formats: List<*>?): BarcodeScannerOptions {
        val optionsBuilder = BarcodeScannerOptions.Builder()
        
        if (formats == null || formats.isEmpty() || formats.contains("allFormats")) {
            optionsBuilder.setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
        } else {
            val barcodeFormats = mutableListOf<Int>()
            formats.forEach { format ->
                when (format) {
                    "aztec" -> barcodeFormats.add(Barcode.FORMAT_AZTEC)
                    "codabar" -> barcodeFormats.add(Barcode.FORMAT_CODABAR)
                    "code128" -> barcodeFormats.add(Barcode.FORMAT_CODE_128)
                    "code39" -> barcodeFormats.add(Barcode.FORMAT_CODE_39)
                    "code93" -> barcodeFormats.add(Barcode.FORMAT_CODE_93)
                    "dataMatrix" -> barcodeFormats.add(Barcode.FORMAT_DATA_MATRIX)
                    "ean13" -> barcodeFormats.add(Barcode.FORMAT_EAN_13)
                    "ean8" -> barcodeFormats.add(Barcode.FORMAT_EAN_8)
                    "itf" -> barcodeFormats.add(Barcode.FORMAT_ITF)
                    "pdf417" -> barcodeFormats.add(Barcode.FORMAT_PDF417)
                    "qrCode" -> barcodeFormats.add(Barcode.FORMAT_QR_CODE)
                    "upca" -> barcodeFormats.add(Barcode.FORMAT_UPC_A)
                    "upce" -> barcodeFormats.add(Barcode.FORMAT_UPC_E)
                }
            }
            if (barcodeFormats.isNotEmpty()) {
                optionsBuilder.setBarcodeFormats(barcodeFormats.fold(0) { acc, format -> acc or format })
            } else {
                optionsBuilder.setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            }
        }
        
        return optionsBuilder.build()
    }

    init {
        android.util.Log.d("VisionBarcodeScanner", "VisionCameraView init - viewId: $viewId")
        setupEventChannel()
        setupMethodChannel()
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

    private fun setupMethodChannel() {
        methodChannel = MethodChannel(messenger, "vision_barcode_scanner/methods_$viewId")
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "stopScanningAndCapture" -> {
                    stopScanningAndCapture(result)
                }
                "toggleTorch" -> {
                    toggleTorch(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun toggleTorch(result: MethodChannel.Result) {
        try {
            val cameraControl = camera?.cameraControl
            
            // Toggle the torch state
            isTorchOn = !isTorchOn
            cameraControl?.enableTorch(isTorchOn)
            
            android.util.Log.d("VisionBarcodeScanner", "Torch toggled: $isTorchOn")
            result.success(isTorchOn)
        } catch (e: Exception) {
            android.util.Log.e("VisionBarcodeScanner", "Error toggling torch", e)
            result.error("TORCH_ERROR", "Failed to toggle torch: ${e.message}", null)
        }
    }

    private fun stopScanningAndCapture(result: MethodChannel.Result) {
        android.util.Log.d("VisionBarcodeScanner", "stopScanningAndCapture called")
        isScanning = false
        
        val imageProxy = lastImageProxy
        if (imageProxy != null) {
            val imageByteArray = imageProxyToByteArray(imageProxy)
            result.success(mapOf("imageData" to imageByteArray))
            lastImageProxy = null
        } else {
            result.error("NO_IMAGE", "No image available", null)
        }
    }

    private fun imageProxyToByteArray(imageProxy: ImageProxy): ByteArray {
        val mediaImage = imageProxy.image ?: throw IllegalArgumentException("Image is null")

        var bitmap: Bitmap? = try {
            android.util.Log.d("VisionBarcodeScanner", "previewView.bitmap set")
            previewView.bitmap
        } catch (e: Exception) {
            null
        }
        var rotatedBitmap: Bitmap

        if(bitmap == null) {
            // Get the bitmap from media image
            android.util.Log.d("VisionBarcodeScanner", "bitmap is null")
            val yBuffer = imageProxy.planes[0].buffer
            val uBuffer = imageProxy.planes[1].buffer
            val vBuffer = imageProxy.planes[2].buffer

            val ySize = yBuffer.remaining()
            val uSize = uBuffer.remaining()
            val vSize = vBuffer.remaining()

            val nv21 = ByteArray(ySize + uSize + vSize)

            yBuffer.get(nv21, 0, ySize)
            vBuffer.get(nv21, ySize, vSize)
            uBuffer.get(nv21, ySize + vSize, uSize)

            val yuvImage = YuvImage(nv21, ImageFormat.NV21, mediaImage.width, mediaImage.height, null)
            val out = ByteArrayOutputStream()

            // Compress to bitmap first to handle rotation
            yuvImage.compressToJpeg(android.graphics.Rect(0, 0, mediaImage.width, mediaImage.height), 90, out)
            val jpegBytes = out.toByteArray()

            // Convert to bitmap and apply rotation
            val bitmap = android.graphics.BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

            // Get rotation from ImageProxy
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees

            // Rotate bitmap if needed
            rotatedBitmap = if (rotationDegrees != 0) {
                val matrix = android.graphics.Matrix()
                matrix.postRotate(rotationDegrees.toFloat())
                android.graphics.Bitmap.createBitmap(
                    bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true
                )
            } else {
                bitmap
            }
        } else {
            rotatedBitmap =  bitmap
        }

        val finalOut = ByteArrayOutputStream()
        rotatedBitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, finalOut)
        
        return finalOut.toByteArray()
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
                            val scannerOptions = getBarcodeScannerOptions(formats)
                            val viewportHeight = (134 * context.resources.displayMetrics.density).toInt()
                            val topMargin = (148 * context.resources.displayMetrics.density).toInt()
                            
                            // Calculate the absolute top position of the camera view on the screen
                            val location = IntArray(2)
                            previewView.getLocationOnScreen(location)
                            val viewAbsoluteTop = location[1]  // Use [1] for Y coordinate, [0] is X
                            val viewAbsoluteLeft = location[0]
                            
                            android.util.Log.d("VisionBarcodeScanner", "View absolute position: ($viewAbsoluteLeft, $viewAbsoluteTop), Top margin: $topMargin, Viewport height: $viewportHeight")
                            android.util.Log.d("VisionBarcodeScanner", "PreviewView size: ${previewView.width}x${previewView.height}, Image resolution: ${resolution.width}x${resolution.height}")
                            
                            it.setAnalyzer(cameraExecutor, BarcodeAnalyzer(
                                scannerOptions = scannerOptions,
                                viewportHeight = viewportHeight,
                                topMargin = topMargin,
                                viewAbsoluteTop = viewAbsoluteTop,
                                viewHeight = previewView.height,
                                imageHeight = resolution.height,
                                imageWidth = resolution.width,
                                onBarcodeDetected = { barcode, barcodeType, imageProxy ->
                                    if (isScanning) {
                                        android.util.Log.d("VisionBarcodeScanner", "Barcode detected: $barcode (type: $barcodeType)")
                                        lastImageProxy = imageProxy
                                        // Send barcode value and type as a map
                                        eventSink?.success(mapOf(
                                            "value" to barcode,
                                            "type" to barcodeType
                                        ))
                                    } else {
                                        imageProxy.close()
                                    }
                                }
                            ))
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

class BarcodeAnalyzer(
    private val scannerOptions: BarcodeScannerOptions,
    private val viewportHeight: Int,
    private val topMargin: Int,
    private val viewAbsoluteTop: Int,
    private val viewHeight: Int,
    private val imageHeight: Int,
    private val imageWidth: Int,
    private val onBarcodeDetected: (String, String, ImageProxy) -> Unit
) : ImageAnalysis.Analyzer {
    private val barcodeScanner = BarcodeScanning.getClient(scannerOptions)
    
    private fun getBarcodeTypeName(format: Int): String {
        return when (format) {
            Barcode.FORMAT_AZTEC -> "aztec"
            Barcode.FORMAT_CODABAR -> "codabar"
            Barcode.FORMAT_CODE_128 -> "code128"
            Barcode.FORMAT_CODE_39 -> "code39"
            Barcode.FORMAT_CODE_93 -> "code93"
            Barcode.FORMAT_DATA_MATRIX -> "dataMatrix"
            Barcode.FORMAT_EAN_13 -> "ean13"
            Barcode.FORMAT_EAN_8 -> "ean8"
            Barcode.FORMAT_ITF -> "itf"
            Barcode.FORMAT_PDF417 -> "pdf417"
            Barcode.FORMAT_QR_CODE -> "qrCode"
            Barcode.FORMAT_UPC_A -> "upca"
            Barcode.FORMAT_UPC_E -> "upce"
            else -> "unknown"
        }
    }

    private fun isBarcodeInViewport(barcode: Barcode, imageHeight: Int, imageWidth: Int, rotationDegrees: Int): Boolean {
        val boundingBox = barcode.boundingBox ?: return false
        
        // Step 1: Get barcode Y coordinate from ML Kit (in image coordinate system)
        val barcodeCenterY = boundingBox.exactCenterY()
        
        // Step 2: Determine the effective image dimension based on rotation
        // At 90/270°, the camera sensor is landscape but image is in portrait orientation
        // At 0/180°, the camera sensor and image are both in portrait orientation
        val effectiveImageHeight = when (rotationDegrees) {
            90, 270 -> imageWidth   // Landscape orientation: width is the vertical axis
            else -> imageHeight      // Portrait orientation: height is the vertical axis
        }
        
        // Step 3: Calculate the viewport center in image coordinates
        // The overlay is positioned at `topMargin` pixels from the top of the Flutter view
        // We need to map this to the image coordinate system
        
        // Step 3a: Calculate where the overlay is within the PreviewView (in pixels)
        // topMargin is in dp, converted to pixels (already done)
        val overlayTopInView = topMargin  // Distance from top of PreviewView to top of overlay
        
        // Step 3b: Map the overlay position from view coordinates to image coordinates
        // PreviewView might be cropped/fitted to the camera preview, so we need to account for scaling
        // The image aspect ratio might differ from the view aspect ratio
        
        // Map the overlay top position to image coordinates using the actual view and image dimensions
        val overlayTopInImage = overlayTopInView * (effectiveImageHeight.toFloat() / viewHeight.toFloat())
        
        // Step 4: Calculate the viewport bounds in image coordinates
        val viewportTop = overlayTopInImage
        val viewportBottom = overlayTopInImage + viewportHeight
        
        // Step 5: Check if barcode center is within the viewport
        val isInViewport = barcodeCenterY >= viewportTop && barcodeCenterY <= viewportBottom
        
        // Detailed logging for debugging
        android.util.Log.d("VisionBarcodeScanner", "=== Viewport Calculation ===")
        android.util.Log.d("VisionBarcodeScanner", "Rotation: $rotationDegrees°, Image size: ${imageWidth}x${imageHeight}")
        android.util.Log.d("VisionBarcodeScanner", "Effective image height: $effectiveImageHeight, View height: $viewHeight")
        android.util.Log.d("VisionBarcodeScanner", "Overlay top in view: ${overlayTopInView}px, In image: ${overlayTopInImage}px")
        android.util.Log.d("VisionBarcodeScanner", "Viewport bounds: [$viewportTop, $viewportBottom]")
        android.util.Log.d("VisionBarcodeScanner", "Barcode center Y: $barcodeCenterY, In viewport: $isInViewport")
        android.util.Log.d("VisionBarcodeScanner", "Barcode bounding box: [${boundingBox.left}, ${boundingBox.top}, ${boundingBox.right}, ${boundingBox.bottom}]")
        
        return isInViewport
    }

    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val image = InputImage.fromMediaImage(mediaImage, rotationDegrees)
            
            barcodeScanner.process(image)
                .addOnSuccessListener { barcodes ->
                    barcodes.firstOrNull()?.let { barcode ->
                        // Check if barcode is within viewport (accounting for rotation)
                        if (isBarcodeInViewport(barcode, mediaImage.height, mediaImage.width, rotationDegrees)) {
                            barcode.rawValue?.let { value ->
                                val barcodeType = getBarcodeTypeName(barcode.format)
                                android.util.Log.d("VisionBarcodeScanner", "Barcode in viewport: $value (type: $barcodeType)")
                                // Don't close the imageProxy here - we need it for capture
                                onBarcodeDetected(value, barcodeType, imageProxy)
                                return@addOnSuccessListener
                            }
                        } else {
                            android.util.Log.d("VisionBarcodeScanner", "Barcode outside viewport, ignoring")
                        }
                    }
                    imageProxy.close()
                }
                .addOnFailureListener { exception ->
                    android.util.Log.e("VisionBarcodeScanner", "Barcode scanning error: ${exception.message}", exception)
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }
}
