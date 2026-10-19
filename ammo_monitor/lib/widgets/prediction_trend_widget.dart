import 'package:flutter/material.dart';

class PredictionTrendWidget extends StatelessWidget {
  final Map<String, dynamic>? predictionData;
  final double currentTemp;
  final double currentHumidity;

  const PredictionTrendWidget({
    super.key,
    required this.predictionData,
    required this.currentTemp,
    required this.currentHumidity,
  });

  @override
  Widget build(BuildContext context) {
    if (predictionData == null) {
      return const SizedBox.shrink();
    }

    final dewPoint = (predictionData!['dew_point_current'] as num?)?.toDouble() ?? 0.0;
    final margin = (predictionData!['temp_margin'] as num?)?.toDouble() ?? 0.0;
    final riskLevel = predictionData!['risk_level'] as String? ?? "NORMAL";
    final isRisk = predictionData!['condensation_risk'] as bool? ?? false;
    final warningMsg = predictionData!['warning_message'] as String? ?? "";
    final forecast = predictionData!['forecast_2h'] as Map<String, dynamic>?;

    final temp2h = (forecast?['temp_2h'] as num?)?.toDouble() ?? currentTemp;
    final hum2h = (forecast?['humidity_2h'] as num?)?.toDouble() ?? currentHumidity;
    final dewPt2h = (forecast?['dew_point_2h'] as num?)?.toDouble() ?? dewPoint;

    Color headerBg = isRisk ? Colors.red.shade800 : (margin <= 4.0 ? Colors.amber.shade900 : Colors.blueGrey.shade800);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: headerBg,
            child: Row(
              children: [
                Icon(
                  isRisk ? Icons.warning_amber_rounded : Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "DỰ BÁO ĐỌNG SƯƠNG & MÔI TRƯỜNG KHO (2-4H)",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    riskLevel,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRisk) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warningMsg,
                            style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("Điểm sương (Dew Point)", "$dewPoint°C", Icons.thermostat_rounded, Colors.indigo),
                    _buildStatItem("Biên độ an toàn (T - Tdp)", "$margin°C", Icons.shield_moon_rounded, margin <= 2.0 ? Colors.red : Colors.green),
                  ],
                ),
                const Divider(height: 20),
                const Text(
                  "Xu hướng dự báo 2 giờ tới:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text("Nhiệt độ: $temp2h°C", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("Độ ẩm: $hum2h%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text("Điểm sương 2h: $dewPt2h°C", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
