import 'package:flutter/material.dart';
import 'transport_list_item.dart';   // đúng path

class TodayTransportScreen extends StatelessWidget {
  const TodayTransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Today's Transport",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TransportListItem(
            status: "Normal",
            statusColor: Colors.green,
          ),
          const SizedBox(height: 16),

          TransportListItem(
            status: "Warning",
            statusColor: Colors.orange,
          ),
          const SizedBox(height: 16),

          TransportListItem(
            status: "Critical",
            statusColor: Colors.red,
          ),
          const SizedBox(height: 16),

          TransportListItem(
            status: "Normal",
            statusColor: Colors.green,
          ),
        ],
      ),
    );
  }
}
