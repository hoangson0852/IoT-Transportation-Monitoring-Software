import 'dart:async';
import 'package:flutter/material.dart';
import '../services/esp32_api.dart';
import 'success_screen.dart';

class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({super.key});

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {

  bool connected = false;
  int retry = 0;

  @override
  void initState() {
    super.initState();

    startPolling();
  }

  void startPolling() {
    Timer.periodic(const Duration(seconds: 3), (timer) async {

      retry++;

      try {
        bool ok = await Esp32Api.getStatus();

        if (ok) {
          timer.cancel();

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const SuccessScreen(),
              ),
            );
          }
        }

        // timeout
        if (retry > 20) {
          timer.cancel();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("ESP32 connect timeout"),
              ),
            );

            Navigator.pop(context);
          }
        }

      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              const CircularProgressIndicator(),

              const SizedBox(height: 40),

              const Text(
                "Configuring ESP32...",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Please wait...",
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}