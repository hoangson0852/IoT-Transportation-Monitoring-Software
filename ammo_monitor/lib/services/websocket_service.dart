import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _telemetryChannel;
  WebSocketChannel? _alertsChannel;

  final StreamController<Map<String, dynamic>> _telemetryController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _alertsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;
  Stream<Map<String, dynamic>> get alertsStream => _alertsController.stream;

  bool _isTelemetryConnected = false;
  bool _isAlertsConnected = false;

  bool get isConnected => _isTelemetryConnected && _isAlertsConnected;
  bool get isAlertsConnected => _isAlertsConnected;

  int _reconnectDelaySec = 1;
  Timer? _reconnectTimer;

  void connect({String baseUrl = "ws://localhost:5001"}) {
    _connectTelemetry("$baseUrl/ws/telemetry");
    _connectAlerts("$baseUrl/ws/alerts");
  }

  void _connectTelemetry(String url) {
    try {
      final uri = Uri.parse(url);
      _telemetryChannel = WebSocketChannel.connect(uri);
      _isTelemetryConnected = true;
      _reconnectDelaySec = 1;
      debugPrint("[WebSocket] Connected to Telemetry endpoint: $url");

      _telemetryChannel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            _telemetryController.add(parsed);
          } catch (e) {
            debugPrint("[WebSocket] Error parsing telemetry message: $e");
          }
        },
        onDone: () {
          debugPrint("[WebSocket] Telemetry stream closed.");
          _isTelemetryConnected = false;
          _scheduleReconnect(url, isTelemetry: true);
        },
        onError: (error) {
          debugPrint("[WebSocket] Telemetry stream error: $error");
          _isTelemetryConnected = false;
          _scheduleReconnect(url, isTelemetry: true);
        },
      );
    } catch (e) {
      debugPrint("[WebSocket] Connection error: $e");
      _isTelemetryConnected = false;
      _scheduleReconnect(url, isTelemetry: true);
    }
  }

  void _connectAlerts(String url) {
    try {
      final uri = Uri.parse(url);
      _alertsChannel = WebSocketChannel.connect(uri);
      _isAlertsConnected = true;
      debugPrint("[WebSocket] Connected to Alerts endpoint: $url");

      _alertsChannel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            _alertsController.add(parsed);
          } catch (e) {
            debugPrint("[WebSocket] Error parsing alert message: $e");
          }
        },
        onDone: () {
          _isAlertsConnected = false;
          _scheduleReconnect(url, isTelemetry: false);
        },
        onError: (error) {
          _isAlertsConnected = false;
          _scheduleReconnect(url, isTelemetry: false);
        },
      );
    } catch (e) {
      _isAlertsConnected = false;
      _scheduleReconnect(url, isTelemetry: false);
    }
  }

  void _scheduleReconnect(String url, {required bool isTelemetry}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySec), () {
      _reconnectDelaySec = (_reconnectDelaySec * 2).clamp(1, 16);
      if (isTelemetry) {
        _connectTelemetry(url);
      } else {
        _connectAlerts(url);
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _telemetryChannel?.sink.close(status.goingAway);
    _alertsChannel?.sink.close(status.goingAway);
    _isTelemetryConnected = false;
    _isAlertsConnected = false;
  }
}
