import 'package:wifi_iot/wifi_iot.dart';

class WifiService {

  static Future<String?> getCurrentSSID() async {
    return await WiFiForIoTPlugin.getSSID();
  }

  static Future<bool> isConnectedToESP32() async {
    final ssid = await getCurrentSSID();

    if (ssid == null) return false;

    return ssid.contains("MIL-RX-Gateway");
  }
}
