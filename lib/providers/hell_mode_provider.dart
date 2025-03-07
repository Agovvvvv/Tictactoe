import 'package:flutter/foundation.dart';

class HellModeProvider extends ChangeNotifier {
  bool _isHellModeActive = false;

  bool get isHellModeActive => _isHellModeActive;

  void toggleHellMode() {
    _isHellModeActive = !_isHellModeActive;
    notifyListeners();
  }

  void setHellMode(bool value) {
    if (_isHellModeActive != value) {
      _isHellModeActive = value;
      notifyListeners();
    }
  }
}
