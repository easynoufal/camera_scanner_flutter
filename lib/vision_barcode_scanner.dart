import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vision_barcode_scanner/vision_barcode_scanner_controller.dart';
export 'package:vision_barcode_scanner/vision_barcode_scanner_controller.dart';

enum BarcodeFormat {
  allFormats,
  aztec,
  codabar,
  code128,
  code39,
  code93,
  dataMatrix,
  ean13,
  ean8,
  itf,
  pdf417,
  qrCode,
  upca,
  upce,
}

class VisionBarcodeScannerView extends StatefulWidget {
  final void Function(String barcode)? onBarcodeDetected;
  final bool shouldShowOverlay;
  final bool shouldShowTorch;
  final VisionBarcodeScannerController? controller;
  final List<BarcodeFormat> formats;

  const VisionBarcodeScannerView({
    super.key,
    this.onBarcodeDetected,
    this.shouldShowOverlay = true,
    this.shouldShowTorch = true,
    this.controller,
    this.formats = const [BarcodeFormat.allFormats],
  });

  @override
  State<VisionBarcodeScannerView> createState() =>
      _VisionBarcodeScannerViewState();
}

class _VisionBarcodeScannerViewState extends State<VisionBarcodeScannerView> {
  static const String _viewType = 'VisionCameraView';
  EventChannel? _eventChannel;
  MethodChannel? _methodChannel;
  StreamSubscription? _subscription;
  bool _isScanning = true;
  Uint8List? _capturedFrame;
  bool _isTorchOn = false;
  
  @override
  void initState() {
    super.initState();
    // Attach this state to the controller if provided
    if (widget.controller != null) {
      widget.controller!.attachState(this);
    }
  }

  @override
  void dispose() {
    turnOffTorch(); // Ensure torch is turned off
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    try {
      final result = await _methodChannel?.invokeMethod<bool>(
        'toggleTorch',
      );

      if (result != null && mounted) {
        setState(() {
          _isTorchOn = result;
        });
      }
    } catch (e) {
      debugPrint('Error toggling torch: $e');
    }
  }

  Future<void> _stopScanningAndCapture() async {
    try {
      final result = await _methodChannel?.invokeMethod<Map<dynamic, dynamic>>(
        'stopScanningAndCapture',
      );

      if (result != null && mounted) {
        setState(() {
          // Handle both List<int> and Uint8List (FlutterStandardTypedData)
          dynamic imageData = result['imageData'];
          if (imageData is List<int>) {
            _capturedFrame = Uint8List.fromList(imageData);
          } else if (imageData is Uint8List) {
            _capturedFrame = imageData;
          }
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('Error stopping scanning: $e');
      // Set scanning to false even on error
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _handleBarcodeDetected(String barcode) {
    // Only process barcode if currently scanning and callback is set
    if (_isScanning && widget.onBarcodeDetected != null && mounted) {
      debugPrint('VisionBarcodeScanner: Barcode detected: $barcode');
      widget.onBarcodeDetected!(barcode);
      _stopScanningAndCapture();
    } else {
      debugPrint('VisionBarcodeScanner: Ignoring barcode detection - isScanning: $_isScanning, hasCallback: ${widget.onBarcodeDetected != null}');
    }
  }

  void startScanning() {
    if (!_isScanning) {
      setState(() {
        _isScanning = true;
        _capturedFrame = null; // Clear captured frame to resume live scanning
      });
    }
  }
  
  void stopScanning() {
    setState(() {
      _isScanning = false;
    });
  }
  
  bool get isScanning => _isScanning;
  
  Future<void> turnOffTorch() async {
    if (_isTorchOn && _methodChannel != null && mounted) {
      try {
        final result = await _methodChannel?.invokeMethod<bool>('toggleTorch');
        if (result != null && mounted) {
          setState(() {
            _isTorchOn = result;
          });
        }
      } catch (e) {
        debugPrint('Error turning off torch: $e');
      }
    }
  }

  Widget _buildTorchIcon() {
    return SvgPicture.asset(
      _isTorchOn
          ? 'packages/vision_barcode_scanner/assets/torch_on.svg'
          : 'packages/vision_barcode_scanner/assets/torch_off.svg',
      width: 40,
      height: 40,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cameraView;

    // Convert formats to string list for native platforms
    final formatsList = widget.formats.map((f) => f.name).toList();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      cameraView = UiKitView(
        viewType: _viewType,
        onPlatformViewCreated: (int viewId) {
          _eventChannel = EventChannel('vision_barcode_scanner/events_$viewId');
          _methodChannel =
              MethodChannel('vision_barcode_scanner/methods_$viewId');
          _subscription = _eventChannel!
              .receiveBroadcastStream()
              .cast<String>()
              .listen(_handleBarcodeDetected);
          
          // Send formats via method channel as workaround for UiKitView creationParams issue
          _methodChannel?.invokeMethod('setFormats', formatsList);
        },
        creationParams: {'formats': formatsList},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      cameraView = AndroidView(
        viewType: _viewType,
        onPlatformViewCreated: (int viewId) {
          _eventChannel = EventChannel('vision_barcode_scanner/events_$viewId');
          _methodChannel =
              MethodChannel('vision_barcode_scanner/methods_$viewId');
          _subscription = _eventChannel!
              .receiveBroadcastStream()
              .cast<String>()
              .listen(_handleBarcodeDetected);
          
          // Send formats via method channel for Android as well
          _methodChannel?.invokeMethod('setFormats', formatsList);
        },
        creationParams: {'formats': formatsList},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      cameraView = const Center(
          child: Text('Camera view only supported on iOS and Android'));
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Show captured frame as frozen preview or live camera
        Positioned.fill(
          child: _capturedFrame != null && !_isScanning
              ? Image.memory(
                  _capturedFrame!,
                  fit: BoxFit.cover,
                )
              : cameraView,
        ),

        if (widget.shouldShowOverlay && (_capturedFrame == null || _isScanning))
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: const _ScannerOverlay(),
            ),
          ),

        // Torch icon button positioned at top right
        if (widget.shouldShowTorch && (_capturedFrame == null || _isScanning))
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _toggleTorch,
              child: _buildTorchIcon(),
            ),
          ),
      ],
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'packages/vision_barcode_scanner/assets/ic_scanner_view.svg',
      width: 238,
      height: 134,
    );
  }
}
