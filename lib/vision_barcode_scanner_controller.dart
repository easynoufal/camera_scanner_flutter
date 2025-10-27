class VisionBarcodeScannerController {
  dynamic _state;
  
  VisionBarcodeScannerController();
  
  void startScanning() {
    _state?.startScanning();
  }
  
  void stopScanning() {
    _state?.stopScanning();
  }
  
  bool get isScanning => _state?.isScanning ?? false;
  
  String? get detectedBarcode => _state?.detectedBarcode;
  
  String? get detectedBarcodeType => _state?.detectedBarcodeType;
  
  void attachState(dynamic state) {
    _state = state;
  }
}
