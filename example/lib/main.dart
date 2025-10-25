import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    controller = VisionBarcodeScannerController();
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
        body: Stack(
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
                      style: const TextStyle(color: Colors.white, fontSize: 20),
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
        ),
      ),
    );
  }
}
