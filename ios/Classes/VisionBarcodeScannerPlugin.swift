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
        return VisionCameraView(
            frame: frame,
            viewId: viewId,
            messenger: messenger
        )
    }
}

public class VisionCameraView: NSObject, FlutterPlatformView, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let frame: CGRect
    private var eventSink: FlutterEventSink?
    private var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    private let eventChannel: FlutterEventChannel
    private weak var containerView: UIView?

    public init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
        self.frame = frame
        self.eventChannel = FlutterEventChannel(
            name: "vision_barcode_scanner/events_\(viewId)",
            binaryMessenger: messenger
        )
        super.init()
        self.eventChannel.setStreamHandler(self)
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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let results = request.results as? [VNBarcodeObservation] else { return }
            for barcode in results {
                if let payload = barcode.payloadStringValue {
                    self?.eventSink?(payload)
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
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