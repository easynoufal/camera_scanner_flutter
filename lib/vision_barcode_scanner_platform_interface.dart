import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'vision_barcode_scanner_method_channel.dart';

abstract class VisionBarcodeScannerPlatform extends PlatformInterface {
  /// Constructs a VisionBarcodeScannerPlatform.
  VisionBarcodeScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static VisionBarcodeScannerPlatform _instance = MethodChannelVisionBarcodeScanner();

  /// The default instance of [VisionBarcodeScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelVisionBarcodeScanner].
  static VisionBarcodeScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VisionBarcodeScannerPlatform] when
  /// they register themselves.
  static set instance(VisionBarcodeScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
