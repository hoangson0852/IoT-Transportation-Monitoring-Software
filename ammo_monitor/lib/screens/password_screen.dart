import 'package:flutter/material.dart';
import '../models/wifi_network.dart';
import '../services/esp32_api.dart';
import 'connecting_screen.dart';

class PasswordScreen extends StatefulWidget {

  final WifiNetwork network;

  const PasswordScreen({
    super.key,
    required this.network,
  });

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {

  final controller = TextEditingController();

  bool loading = false;

  Future<void> connectWifi() async {

    setState(() => loading = true);

    bool ok = await Esp32Api.sendWifi(
      ssid: widget.network.ssid,
      password: controller.text,
    );

    setState(() => loading = false);

    if (ok) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ConnectingScreen(),
        ),
      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send WiFi"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Enter Password")),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [

            Text(
              widget.network.ssid,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: controller,
              obscureText: true,

              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Password",
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton(
                onPressed: loading ? null : connectWifi,

                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "Connect",
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