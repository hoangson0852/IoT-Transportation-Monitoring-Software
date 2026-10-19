import 'package:flutter/material.dart';
import '../../models/transport_data.dart';
import '../../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<TransportData>>(
        stream: FirestoreService().streamAllVehicles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final devices = snapshot.data!;

          final total = devices.length;
          final active = devices.where((d) => d.isOnline).length;
          final critical =
              devices.where((d) => d.isCritical).length;
          final offline = total - active;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text("Dashboard",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                _overviewGrid(total, active, offline, critical),

                const SizedBox(height: 20),

                _card(
                  "Device Status",
                  SizedBox(
                    height: 180,
                    child: CustomPaint(
                      painter: DonutPainter(
                        active,
                        offline,
                        critical,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                _card(
                  "Alert Trend",
                  SizedBox(
                    height: 180,
                    child: CustomPaint(
                      painter: LineChartPainter(
                          [5, 10, 8, 14, 12, critical.toDouble()]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overviewGrid(int t, int a, int o, int c) {
    Widget box(String title, int value, IconData icon) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text("$value",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title),
          ],
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        box("Total", t, Icons.devices),
        box("Active", a, Icons.check_circle),
        box("Offline", o, Icons.cloud_off),
        box("Critical", c, Icons.warning),
      ],
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// =======================================================
// 🎯 CHARTS
// =======================================================

class DonutPainter extends CustomPainter {
  final int a, o, c;
  DonutPainter(this.a, this.o, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final total = (a + o + c).toDouble().clamp(1, 999);
    final rect = Offset.zero & size;
    const stroke = 22.0;
    double start = -1.57;

    for (final entry in [
      [a, Colors.green],
      [o, Colors.grey],
      [c, Colors.red],
    ]) {
      final sweep = 6.283 * ((entry[0] as num) / total);
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = entry[1] as Color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class LineChartPainter extends CustomPainter {
  final List<double> pts;
  LineChartPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = pts.reduce((a, b) => a > b ? a : b);
    final stepX = size.width / (pts.length - 1);

    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = stepX * i;
      final y =
          size.height - (pts[i] / maxVal) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}
