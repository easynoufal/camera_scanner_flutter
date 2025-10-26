import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vision_barcode_scanner/vision_barcode_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? scannedCode;
  late VisionBarcodeScannerController controller;
  bool _hasPermission = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    controller = VisionBarcodeScannerController();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _hasPermission = status.isGranted;
    });
  }

  Future<void> _requestCameraPermission() async {
    setState(() {
      _isRequestingPermission = true;
    });
    
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
      _isRequestingPermission = false;
    });
  }

  void _onBarcodeDetected(String barcode) {
    setState(() {
      scannedCode = barcode;
    });
  }
  
  void _startScanningAgain() {
    setState(() {
      scannedCode = null;
    });
    controller.startScanning();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Vision Barcode Scanner')),
        body: _hasPermission
            ? Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.62,
                    child: VisionBarcodeScannerView(
                      controller: controller,
                      onBarcodeDetected: _onBarcodeDetected,
                      //support for barcode only. other formats will be ignored.
                      formats: const [
                        BarcodeFormat.code128,
                        BarcodeFormat.code39,
                        BarcodeFormat.ean13,
                        BarcodeFormat.ean8,
                        BarcodeFormat.code93,
                        BarcodeFormat.itf,
                        BarcodeFormat.codabar,
                        BarcodeFormat.dataMatrix,
                        BarcodeFormat.pdf417,
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            scannedCode ?? 'Scanning...',
                            style:
                                const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                          if (scannedCode != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: ElevatedButton(
                                onPressed: _startScanningAgain,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Scan Again'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Camera Permission Required',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please grant camera permission to scan barcodes.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isRequestingPermission ? null : _requestCameraPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: _isRequestingPermission
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Grant Permission'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
