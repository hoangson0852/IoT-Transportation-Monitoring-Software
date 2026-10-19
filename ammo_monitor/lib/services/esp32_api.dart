import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wifi_network.dart';

class Esp32Api {
  static const String baseUrl = "http://192.168.4.1";

  // ================= STATUS =================
  static Future<bool> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/status"),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ================= SCAN WIFI =================
  static Future<List<WifiNetwork>> scanWifi() async {
    final response = await http.get(
      Uri.parse("$baseUrl/scan"),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);

      return data
          .map((e) => WifiNetwork.fromJson(e))
          .toList();
    }

    throw Exception("Scan failed");
  }

  // ================= SEND WIFI =================
  static Future<bool> sendWifi({
    required String ssid,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/wifi"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "ssid": ssid,
        "password": password,
      }),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 200;
  }
}
