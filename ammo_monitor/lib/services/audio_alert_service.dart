import 'dart:async';
import 'package:flutter/foundation.dart';

class AudioAlertService {
  static final AudioAlertService _instance = AudioAlertService._internal();
  factory AudioAlertService() => _instance;
  AudioAlertService._internal();

  bool _isMuted = false;
  bool _isPlayingSiren = false;
  Timer? _sirenTimer;

  bool get isMuted => _isMuted;
  bool get isPlayingSiren => _isPlayingSiren;

  void triggerEmergencySiren() {
    if (_isMuted) return;
    _isPlayingSiren = true;
    if (kDebugMode) {
      print("🚨 [AUDIO SIREN EMERGENCY] Còi báo động khẩn cấp đang hú!");
    }
  }

  void stopSiren() {
    _isPlayingSiren = false;
    _sirenTimer?.cancel();
    if (kDebugMode) {
      print("🔇 [AUDIO SIREN] Đã ngắt còi báo động khẩn cấp.");
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stopSiren();
    }
  }
}
