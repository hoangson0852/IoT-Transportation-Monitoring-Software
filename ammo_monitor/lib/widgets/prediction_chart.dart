import 'package:flutter/material.dart';

class PredictionChartWidget extends StatelessWidget {
  final double currentTemp;
  final double currentHum;
  final double dewPoint;
  final bool condensationRisk;
  final String warningMessage;
  final double forecastTemp2h;
  final double forecastHum2h;

  const PredictionChartWidget({
    super.key,
    required this.currentTemp,
    required this.currentHum,
    required this.dewPoint,
    required this.condensationRisk,
    required this.warningMessage,
    required this.forecastTemp2h,
    required this.forecastHum2h,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: condensationRisk ? Colors.red.shade50 : Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  condensationRisk ? Icons.warning_rounded : Icons.auto_graph_rounded,
                  color: condensationRisk ? Colors.red : Colors.blue.shade700,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  "Dự báo Xu hướng & Điểm Sương (Dew Point)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: condensationRisk ? Colors.red.shade900 : Colors.blueGrey.shade900,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            if (condensationRisk)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn("Nhiệt độ hiện tại", "${currentTemp.toStringAsFixed(1)}°C", Colors.black87),
                _buildInfoColumn("Độ ẩm", "${currentHum.toStringAsFixed(1)}%", Colors.black87),
                _buildInfoColumn("Điểm Sương", "${dewPoint.toStringAsFixed(1)}°C", Colors.blue.shade800),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    "Dự báo 2h tới: ${forecastTemp2h.toStringAsFixed(1)}°C",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo),
                  ),
                  Text(
                    "Độ ẩm 2h: ${forecastHum2h.toStringAsFixed(1)}%",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
