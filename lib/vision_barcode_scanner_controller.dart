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
  
  void attachState(dynamic state) {
    _state = state;
  }
}
