class WifiNetwork {
  final String ssid;
  final int rssi;
  final bool secure;

  WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.secure,
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'],
      rssi: json['rssi'],
      secure: json['secure'],
    );
  }
}
