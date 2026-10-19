import 'package:flutter/material.dart';

class QosMonitorWidget extends StatelessWidget {
  final double battery;
  final int rssi;
  final double snr;
  final double packetLossRatePct;
  final String lastUpdated;

  const QosMonitorWidget({
    super.key,
    required this.battery,
    required this.rssi,
    required this.snr,
    this.packetLossRatePct = 0.0,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    Color batteryColor = battery > 50
        ? Colors.green
        : (battery > 20 ? Colors.orange : Colors.red);

    Color signalColor = rssi > -100 ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.network_check_rounded, size: 18, color: Colors.blueAccent),
                SizedBox(width: 6),
                Text(
                  "CHỈ SỐ SỨC KHỎE THIẾT BỊ & GIÁM SÁT QOS",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQosTile(
                  icon: Icons.battery_charging_full_rounded,
                  label: "Pin",
                  value: "${battery.toStringAsFixed(0)}%",
                  color: batteryColor,
                ),
                _buildQosTile(
                  icon: Icons.cell_tower_rounded,
                  label: "RSSI / SNR",
                  value: "$rssi / ${snr.toStringAsFixed(1)} dB",
                  color: signalColor,
                ),
                _buildQosTile(
                  icon: Icons.percent_rounded,
                  label: "Mất gói (PER)",
                  value: "${packetLossRatePct.toStringAsFixed(1)}%",
                  color: packetLossRatePct < 5.0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Heartbeat mới nhất: $lastUpdated",
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQosTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
