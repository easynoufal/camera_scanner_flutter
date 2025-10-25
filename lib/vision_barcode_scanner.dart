import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VisionBarcodeScannerView extends StatefulWidget {
  final void Function(String barcode)? onBarcodeDetected;

  const VisionBarcodeScannerView({super.key, this.onBarcodeDetected});

  @override
  State<VisionBarcodeScannerView> createState() => _VisionBarcodeScannerViewState();
}

class _VisionBarcodeScannerViewState extends State<VisionBarcodeScannerView> {
  static const String _viewType = 'VisionCameraView';
  static int _viewIdCounter = 0;
  EventChannel? _eventChannel;
  StreamSubscription? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: _viewType,
        onPlatformViewCreated: (int viewId) {
          _eventChannel = EventChannel('vision_barcode_scanner/events_$viewId');
          _subscription = _eventChannel!
              .receiveBroadcastStream()
              .cast<String>()
              .listen((barcode) {
            if (widget.onBarcodeDetected != null) {
              widget.onBarcodeDetected!(barcode);
            }
          });
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: _viewType,
        onPlatformViewCreated: (int viewId) {
          _eventChannel = EventChannel('vision_barcode_scanner/events_$viewId');
          _subscription = _eventChannel!
              .receiveBroadcastStream()
              .cast<String>()
              .listen((barcode) {
            if (widget.onBarcodeDetected != null) {
              widget.onBarcodeDetected!(barcode);
            }
          });
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const Center(child: Text('Camera view only supported on iOS and Android'));
    }
  }
}
