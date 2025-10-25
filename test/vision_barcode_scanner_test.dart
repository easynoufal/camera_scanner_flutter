import 'package:flutter_test/flutter_test.dart';
import 'package:vision_barcode_scanner/vision_barcode_scanner.dart';
import 'package:vision_barcode_scanner/vision_barcode_scanner_platform_interface.dart';
import 'package:vision_barcode_scanner/vision_barcode_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVisionBarcodeScannerPlatform
    with MockPlatformInterfaceMixin
    implements VisionBarcodeScannerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VisionBarcodeScannerPlatform initialPlatform = VisionBarcodeScannerPlatform.instance;

  test('$MethodChannelVisionBarcodeScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVisionBarcodeScanner>());
  });

  test('getPlatformVersion', () async {
    VisionBarcodeScanner visionBarcodeScannerPlugin = VisionBarcodeScanner();
    MockVisionBarcodeScannerPlatform fakePlatform = MockVisionBarcodeScannerPlatform();
    VisionBarcodeScannerPlatform.instance = fakePlatform;

    expect(await visionBarcodeScannerPlugin.getPlatformVersion(), '42');
  });
}
