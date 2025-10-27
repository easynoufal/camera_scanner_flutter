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
            print("Preview layer frame updated to: \(previewLayer.frame)")
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
    private let formats: [String]?

    public init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, formats: [String]?) {
        self.frame = frame
        self.viewId = viewId
        self.formats = formats
        self.eventChannel = FlutterEventChannel(
            name: "vision_barcode_scanner/events_\(viewId)",
            binaryMessenger: messenger
        )
        super.init()
        self.eventChannel.setStreamHandler(self)
        
        // Setup method channel
        self.methodChannel = FlutterMethodChannel(
            name: "vision_barcode_scanner/methods_\(viewId)",
            binaryMessenger: messenger
        )
        self.methodChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "stopScanningAndCapture":
                self?.stopScanningAndCapture(result: result)
            case "toggleTorch":
                self?.toggleTorch(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        setupCamera()
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
            
            print("Preview layer added to view with frame: \(previewLayer.frame)")
        }
    }

    private func setupCamera() {
        print("Setting up camera...")
        // Request camera permission
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    print("Camera permission granted")
                    self?.startCameraSession()
                } else {
                    print("Camera permission denied")
                }
            }
        }
    }
    
    private func startCameraSession() {
        print("Starting camera session...")
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else { 
            print("Failed to get video device or input")
            return 
        }
        
        self.videoDevice = videoDevice

        if captureSession?.canAddInput(videoInput) == true {
            captureSession?.addInput(videoInput)
            print("Video input added to session")
        } else {
            print("Failed to add video input to session")
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "barcodeQueue"))
        
        if captureSession?.canAddOutput(output) == true {
            captureSession?.addOutput(output)
            print("Video output added to session")
        } else {
            print("Failed to add video output to session")
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.videoGravity = .resizeAspectFill
        print("Preview layer created")
        
        // Add preview layer to container view if it exists
        if let containerView = containerView {
            print("Adding preview layer to existing container view")
            addPreviewLayer(to: containerView)
        } else {
            print("Container view not available yet")
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            print("Camera session started")
        }
    }

    // Process camera frames
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isScanning {
            // Keep the last sample buffer for capture
            lastSampleBuffer = sampleBuffer
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self, self.isScanning else { return }
            guard let results = request.results as? [VNBarcodeObservation] else { return }
            for barcode in results {
                // Check if barcode is in viewport (134dp height centered)
                if self.isBarcodeInViewport(barcode, imageHeight: CVPixelBufferGetHeight(pixelBuffer)) {
                    // Filter by supported format if specified
                    if self.shouldProcessBarcode(barcode) {
                        if let payload = barcode.payloadStringValue {
                            let barcodeType = self.symbologyToString(barcode.symbology)
                            print("Barcode detected: \(payload) (type: \(barcodeType))")
                            // Send barcode value and type as a dictionary
                            self.eventSink?([
                                "value": payload,
                                "type": barcodeType
                            ])
                        }
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
            if !symbologies.isEmpty {
                request.symbologies = symbologies
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    private func symbologyFromString(_ format: String) -> VNBarcodeSymbology? {
        switch format {
        case "aztec": return .aztec
        case "codabar": return .codabar
        case "code128": return .Code128
        case "code39": return .Code39
        case "code93": return .Code93
        case "dataMatrix": return .dataMatrix
        case "ean13": return .EAN13
        case "ean8": return .EAN8
        case "itf": return .ITF14
        case "pdf417": return .PDF417
        case "qrCode": return .QR
        case "upca": return .UPCE
        case "upce": return .UPCA
        default: return nil
        }
    }
    
    private func symbologyToString(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .aztec: return "aztec"
        case .codabar: return "codabar"
        case .Code128: return "code128"
        case .Code39: return "code39"
        case .Code93: return "code93"
        case .dataMatrix: return "dataMatrix"
        case .EAN13: return "ean13"
        case .EAN8: return "ean8"
        case .ITF14: return "itf"
        case .PDF417: return "pdf417"
        case .QR: return "qrCode"
        case .UPCE: return "upca"
        case .UPCA: return "upce"
        default: return "unknown"
        }
    }
    
    private func shouldProcessBarcode(_ barcode: VNBarcodeObservation) -> Bool {
        guard let formats = formats, !formats.isEmpty else { return true }
        
        if formats.contains("allFormats") {
            return true
        }
        
        // Check if barcode's symbology matches any requested format
        for format in formats {
            if symbologyFromString(format) == barcode.symbology {
                return true
            }
        }
        
        return false
    }
    
    private func isBarcodeInViewport(_ barcode: VNBarcodeObservation, imageHeight: Int) -> Bool {
        // 134dp converted to pixels based on screen density
        let viewportHeight: CGFloat = 134.0 * UIScreen.main.scale
        let viewportHeightInPixels = Int(viewportHeight)
        
        // Calculate viewport bounds (centered vertically)
        let viewportTop = (imageHeight - viewportHeightInPixels) / 2
        let viewportBottom = viewportTop + viewportHeightInPixels
        
        // Bounding box is in normalized coordinates (0-1), convert to pixel coordinates
        let boundingBox = barcode.boundingBox
        let barcodeCenterY = Int(boundingBox.midY * CGFloat(imageHeight))
        
        // Check if barcode center is within viewport
        print("Barcode center Y: \(barcodeCenterY), Viewport: [\(viewportTop), \(viewportBottom)]")
        
        return barcodeCenterY >= viewportTop && barcodeCenterY <= viewportBottom
    }
    
    private func stopScanningAndCapture(result: @escaping FlutterResult) {
        print("stopScanningAndCapture called")
        isScanning = false
        
        guard let sampleBuffer = lastSampleBuffer else {
            result(FlutterError(code: "NO_IMAGE", message: "No image available", details: nil))
            return
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Invalid image buffer", details: nil))
            return
        }
        
        // Get image orientation from sample buffer
        var orientation = CGImagePropertyOrientation.up
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
           let exifDict = attachments.first,
           let orientationRaw = exifDict[kCGImagePropertyOrientation as String] as? UInt32 {
            orientation = CGImagePropertyOrientation(rawValue: orientationRaw) ?? .up
        }
        
        // Convert CIImage to UIImage with correct orientation
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            result(FlutterError(code: "IMAGE_CONVERSION", message: "Failed to convert image", details: nil))
            return
        }
        
        // Create UIImage with proper orientation
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: UIImage.Orientation(rawValue: orientation.rawValue) ?? .up)
        
        // Convert UIImage to JPEG data
        if let imageData = uiImage.jpegData(compressionQuality: 0.9) {
            result(["imageData": FlutterStandardTypedData(bytes: imageData)])
        } else {
            result(FlutterError(code: "IMAGE_ENCODING", message: "Failed to encode image", details: nil))
        }
        
        lastSampleBuffer = nil
    }
    
    private func toggleTorch(result: @escaping FlutterResult) {
        print("toggleTorch called")
        
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
            let newState = !device.isTorchOn
            try device.setTorchModeOn(level: 1.0)
            if !newState {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            
            print("Torch toggled: \(newState)")
            result(newState)
        } catch {
            print("Error toggling torch: \(error)")
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