import 'package:flutter/material.dart';

class TransportListItem extends StatelessWidget {
  final String status;
  final Color statusColor;

  const TransportListItem({
    super.key,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("[Car Name] - [Transport ID]",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.blue),
              const SizedBox(width: 6),

              // On Route
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("On Route",
                    style: TextStyle(color: Colors.blue, fontSize: 12)),
              ),
              const SizedBox(width: 6),

              // Status Chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.4,
            backgroundColor: Colors.grey.shade300,
            color: Colors.blue,
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(radius: 12, backgroundColor: Colors.orange),
              const SizedBox(width: 6),
              const CircleAvatar(radius: 12, backgroundColor: Colors.purple),
              const SizedBox(width: 6),
              const CircleAvatar(radius: 12, backgroundColor: Colors.green),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  const Text("27 Apr", style: TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Icon(Icons.chat_bubble,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  const Text("2", style: TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
