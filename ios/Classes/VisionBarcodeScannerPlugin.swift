// import Flutter
// import UIKit
// import AVFoundation
// import Vision

// public class VisionBarcodeScannerPlugin: NSObject, FlutterPlugin, AVCaptureVideoDataOutputSampleBufferDelegate {
    
//     var eventSink: FlutterEventSink?
//     var captureSession: AVCaptureSession?
//     var previewLayer: AVCaptureVideoPreviewLayer?
    
//     public static func register(with registrar: FlutterPluginRegistrar) {
//         let instance = VisionBarcodeScannerPlugin()
//         let channel = FlutterMethodChannel(name: "vision_barcode_scanner", binaryMessenger: registrar.messenger())
//         registrar.addMethodCallDelegate(instance, channel: channel)
        
//         let eventChannel = FlutterEventChannel(name: "vision_barcode_scanner/events", binaryMessenger: registrar.messenger())
//         eventChannel.setStreamHandler(instance)
//     }
    
//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         switch call.method {
//         case "startScan":
//             startCameraSession()
//             result(nil)
//         case "stopScan":
//             stopCameraSession()
//             result(nil)
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }
    
//     private func startCameraSession() {
//         captureSession = AVCaptureSession()
//         guard let videoDevice = AVCaptureDevice.default(for: .video),
//               let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
//         else { return }
        
//         captureSession?.addInput(videoInput)
        
//         let videoOutput = AVCaptureVideoDataOutput()
//         videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
//         captureSession?.addOutput(videoOutput)
        
//         captureSession?.startRunning()
//     }
    
//     private func stopCameraSession() {
//         captureSession?.stopRunning()
//         captureSession = nil
//     }
    
//     // Process video frames
//     public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//         guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//         let request = VNDetectBarcodesRequest { request, error in
//             if let results = request.results as? [VNBarcodeObservation] {
//                 for barcode in results {
//                     if let payload = barcode.payloadStringValue {
//                         self.eventSink?(payload)
//                     }
//                 }
//             }
//         }
        
//         let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
//         try? handler.perform([request])
//     }
// }

// extension VisionBarcodeScannerPlugin: FlutterStreamHandler {
//     public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
//         self.eventSink = events
//         return nil
//     }
    
//     public func onCancel(withArguments arguments: Any?) -> FlutterError? {
//         self.eventSink = nil
//         return nil
//     }
// }

import Flutter
import UIKit
import AVFoundation
import Vision

class CameraContainerView: UIView {
    weak var cameraView: VisionCameraView?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update preview layer frame when view layout changes
        if let cameraView = cameraView,
           let previewLayer = cameraView.previewLayer {
            previewLayer.frame = bounds
        }
    }
}

public class VisionCameraViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let argsDict = args as? [String: Any]
        let formats = argsDict?["formats"] as? [String]
        
        return VisionCameraView(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            formats: formats
        )
    }
}

public class VisionCameraView: NSObject, FlutterPlatformView, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let frame: CGRect
    private var eventSink: FlutterEventSink?
    private var methodChannel: FlutterMethodChannel?
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    private let eventChannel: FlutterEventChannel
    private weak var containerView: UIView?
    private var isScanning = true
    private var lastSampleBuffer: CMSampleBuffer?
    private let viewId: Int64
    private var formats: [String]?

    public init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, formats: [String]?) {
        self.frame = frame
        self.viewId = viewId
        self.formats = formats
        self.eventChannel = FlutterEventChannel(
            name: "vision_barcode_scanner/events_\(viewId)",
            binaryMessenger: messenger
        )
        super.init()
        
        // Setup method channel
        self.methodChannel = FlutterMethodChannel(
            name: "vision_barcode_scanner/methods_\(viewId)",
            binaryMessenger: messenger
        )
        
        // Setup everything asynchronously to avoid initialization issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Set stream handler after init
            self.eventChannel.setStreamHandler(self)
            
            // Set method call handler
            self.methodChannel?.setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "stopScanningAndCapture":
                    self?.stopScanningAndCapture(result: result)
                case "toggleTorch":
                    self?.toggleTorch(result: result)
                case "setFormats":
                    // Handle formats being passed via method call
                    if let formats = call.arguments as? [String] {
                        self?.formats = formats
                        result(true)
                    } else {
                        result(false)
                    }
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
            
            // Setup camera
            self.setupCamera()
        }
    }
    
    deinit {
        captureSession?.stopRunning()
    }

    public func view() -> UIView {
        // Create custom container view that handles layout changes
        let customView = CameraContainerView(frame: frame)
        customView.backgroundColor = UIColor.black
        customView.cameraView = self
        self.containerView = customView
        
        // Add preview layer if available
        if let previewLayer = previewLayer {
            addPreviewLayer(to: customView)
        }
        
        return customView
    }
    
    private func addPreviewLayer(to view: UIView) {
        guard let previewLayer = previewLayer else { return }
        
        DispatchQueue.main.async { [weak self, weak view] in
            guard let self = self, let view = view else { return }
            
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
    }

    private func setupCamera() {
        // Check current permission status
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            // Permission already granted, start camera
            startCameraSession()
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startCameraSession()
                    }
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    private func startCameraSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            return
        }
        
        self.videoDevice = videoDevice

        if captureSession?.canAddInput(videoInput) == true {
            captureSession?.addInput(videoInput)
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "barcodeQueue"))
        
        if captureSession?.canAddOutput(output) == true {
            captureSession?.addOutput(output)
            // Set video orientation to portrait
            if let connection = output.connection(with: .video) {
                connection.videoOrientation = .portrait
            }
        }

        guard let session = captureSession else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.connection?.videoOrientation = .portrait
        
        // Add preview layer to container view if it exists
            if let containerView = containerView {
                addPreviewLayer(to: containerView)
            }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    // Process camera frames
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isScanning {
            // Keep the last sample buffer for capture
            lastSampleBuffer = sampleBuffer
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            return 
        }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self, self.isScanning else { return }
            
            if let error = error {
                return
            }
            
            guard let results = request.results as? [VNBarcodeObservation] else { return }
            
            // NEVER allow QR codes unless explicitly in formats
            let isQRAllowed = self.formats?.contains("qrCode") == true || self.formats?.contains("allFormats") == true
            
            for barcode in results {
                // ABSOLUTE BLOCK: Reject QR codes if not in formats
                if barcode.symbology == .QR && !isQRAllowed {
                    continue
                }
                
                // Process other barcode types through normal filtering
                if self.shouldProcessBarcode(barcode) {
                    if let payload = barcode.payloadStringValue {
                        self.eventSink?(payload)
                    }
                }
            }
        }
        
        // Set symbologies if formats are specified
        if let formats = formats, !formats.isEmpty && !formats.contains("allFormats") {
            var symbologies: [VNBarcodeSymbology] = []
            for format in formats {
                if let symbology = symbologyFromString(format) {
                    symbologies.append(symbology)
                }
            }
            // Force set symbologies - this tells Vision to ONLY detect these types
            if !symbologies.isEmpty {
                request.symbologies = symbologies
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            // Handle Vision error silently
        }
    }
    
    private func symbologyFromString(_ format: String) -> VNBarcodeSymbology? {
        switch format {
        case "aztec": return .aztec
        case "code128": return .Code128
        case "code39": return .Code39
        case "code93": return .Code93
        case "dataMatrix": return .dataMatrix
        case "ean13": return .EAN13
        case "ean8": return .EAN8
        case "itf": return .ITF14
        case "pdf417": return .PDF417
        case "qrCode": return .QR
        case "upca": return .EAN13  // UPC-A is compatible with EAN-13
        case "upce": return .EAN8   // UPC-E is compatible with EAN-8
        default:
            if #available(iOS 15.0, *) {
                if format == "codabar" {
                    return .codabar
                }
            }
            return nil
        }
    }
    
    private func shouldProcessBarcode(_ barcode: VNBarcodeObservation) -> Bool {
        // If formats are specified, check them
        guard let formats = formats, !formats.isEmpty else { 
            // No formats specified - allow all barcode types
            return true
        }
        
        if formats.contains("allFormats") {
            return true
        }
        
        // Check if barcode's symbology matches any requested format
        for format in formats {
            if symbologyFromString(format) == barcode.symbology {
                return true
            }
        }
        
        // Symbol not in the allowed formats list
        return false
    }
    
    private func stopScanningAndCapture(result: @escaping FlutterResult) {
        isScanning = false
        
        guard let sampleBuffer = lastSampleBuffer else {
            result(FlutterError(code: "NO_IMAGE", message: "No image available", details: nil))
            return
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Invalid image buffer", details: nil))
            return
        }
        
        // Convert CIImage to UIImage - NO orientation adjustment
        // Camera captures in native sensor orientation (landscape)
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            result(FlutterError(code: "IMAGE_CONVERSION", message: "Failed to convert image", details: nil))
            return
        }
        
        // Create UIImage from raw camera buffer - no rotation
        let uiImage = UIImage(cgImage: cgImage)
        
        // Convert UIImage to JPEG data with maximum quality
        if let imageData = uiImage.jpegData(compressionQuality: 1.0) {
            result(["imageData": FlutterStandardTypedData(bytes: imageData)])
        } else {
            result(FlutterError(code: "IMAGE_ENCODING", message: "Failed to encode image", details: nil))
        }
        
        lastSampleBuffer = nil
    }
    
    private func toggleTorch(result: @escaping FlutterResult) {
        guard let device = videoDevice else {
            result(FlutterError(code: "NO_DEVICE", message: "No video device available", details: nil))
            return
        }
        
        guard device.hasTorch else {
            result(FlutterError(code: "NO_TORCH", message: "Device does not have torch", details: nil))
            return
        }
        
        do {
            try device.lockForConfiguration()
            let currentTorchMode = device.torchMode
            let newState = (currentTorchMode == .off)
            
            if newState {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            
            result(newState)
        } catch {
            result(FlutterError(code: "TORCH_ERROR", message: "Failed to toggle torch: \(error.localizedDescription)", details: nil))
        }
    }
}

extension VisionCameraView: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
 
public class VisionBarcodeScannerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = VisionCameraViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "VisionCameraView")
    }
}