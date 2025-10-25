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

  void _onBarcodeDetected(String barcode) {
    setState(() {
      scannedCode = barcode;
    });
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
                onBarcodeDetected: _onBarcodeDetected,
              ),
            ),          
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: Text(
                  scannedCode ?? 'Scanning...',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
