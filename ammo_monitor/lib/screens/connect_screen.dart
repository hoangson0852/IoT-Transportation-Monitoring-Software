import 'package:flutter/material.dart';
import '../services/esp32_api.dart';
import '../services/wifi_service.dart';
import 'scan_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {

  bool loading = false;

  Future<void> checkESP32() async {
    setState(() => loading = true);

    bool connected = await WifiService.isConnectedToESP32();

    if (!connected) {
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Chưa connect ESP32 WiFi"),
        ),
      );

      return;
    }

    bool ok = await Esp32Api.getStatus();

    setState(() => loading = false);

    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ESP32 không phản hồi"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ESP32 Setup")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Connect to ESP32 WiFi",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              "SSID: MIL-RX-Gateway",
              style: TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 10),

            const Text(
              "Password: mil_config_123",
              style: TextStyle(fontSize: 20),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: loading ? null : checkESP32,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "I've Connected",
                        style: TextStyle(fontSize: 20),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}