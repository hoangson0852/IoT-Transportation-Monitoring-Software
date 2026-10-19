import 'package:flutter/material.dart';
import '../services/esp32_api.dart';
import '../models/wifi_network.dart';
import 'password_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {

  List<WifiNetwork> networks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    scan();
  }

  Future<void> scan() async {
    try {
      final result = await Esp32Api.scanWifi();

      setState(() {
        networks = result;
        loading = false;
      });

    } catch (e) {
      setState(() => loading = false);
    }
  }

  String signalLevel(int rssi) {
    if (rssi > -50) return "Strong";
    if (rssi > -70) return "Medium";
    return "Weak";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Networks"),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: networks.length,
              itemBuilder: (_, index) {

                final wifi = networks[index];

                return ListTile(
                  leading: const Icon(Icons.wifi),
                  title: Text(wifi.ssid),
                  subtitle: Text(signalLevel(wifi.rssi)),

                  trailing: wifi.secure
                      ? const Icon(Icons.lock)
                      : null,

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PasswordScreen(
                          network: wifi,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}