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
  final void Function(String barcode, bool? isQRCode)? onBarcodeDetected;
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
  static int _viewIdCounter = 0;
  EventChannel? _eventChannel;
  MethodChannel? _methodChannel;
  StreamSubscription? _subscription;
  bool _isScanning = true;
  Uint8List? _capturedFrame;
  String? _detectedBarcode;
  String? _detectedBarcodeType;
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

  void _handleBarcodeDetected(dynamic data) {
    if (_isScanning && widget.onBarcodeDetected != null) {
      // Handle both old format (String) and new format (Map with value and type)
      String barcodeValue;
      String? barcodeType;
      
      if (data is Map) {
        barcodeValue = data['value'] as String;
        barcodeType = data['type'] as String?;
      } else if (data is String) {
        barcodeValue = data;
        barcodeType = null;
      } else {
        return;
      }
      
      setState(() {
        _detectedBarcode = barcodeValue;
        _detectedBarcodeType = barcodeType;
      });
      
      // Check if it's a QR code
      bool isQRCode = barcodeType?.toLowerCase() == 'qrcode';
      
      // Call callback with barcode value and isQRCode flag
      widget.onBarcodeDetected!(barcodeValue, isQRCode);
      _stopScanningAndCapture();
    }
  }

  void startScanning() {
    setState(() {
      _isScanning = true;
      _capturedFrame = null;
      _detectedBarcode = null;
      _detectedBarcodeType = null;
    });
  }
  
  void stopScanning() {
    setState(() {
      _isScanning = false;
    });
  }
  
  String? get detectedBarcode => _detectedBarcode;
  String? get detectedBarcodeType => _detectedBarcodeType;

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
              .listen(_handleBarcodeDetected);
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
              .listen(_handleBarcodeDetected);
        },
        creationParams: {'formats': formatsList},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      cameraView = const Center(
          child: Text('Camera view only supported on iOS and Android'));
    }

    return Stack(
      children: [
        // Show captured frame as frozen preview or live camera
        if (_capturedFrame != null && !_isScanning)
          Image.memory(
            _capturedFrame!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        else
          cameraView,

        if (widget.shouldShowOverlay && (_capturedFrame == null || _isScanning))
          Positioned(
            top: 148,
            left: 0,
            right: 0,
            child: _ScannerOverlay(),
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
