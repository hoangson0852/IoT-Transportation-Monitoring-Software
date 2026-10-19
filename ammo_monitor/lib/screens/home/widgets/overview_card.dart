import 'package:flutter/material.dart';

import 'overview_item.dart';

class OverviewCard extends StatelessWidget {
  final int transportingCount;
  final int deviceCount;
  final int alertCount;

  const OverviewCard({
    super.key,
    required this.transportingCount,
    required this.deviceCount,
    required this.alertCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C70D1),
            Color(0xFF4BA3FF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C70D1).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Real-time transportation monitoring status',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.82),
            ),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: OverviewItem(
                  title: 'Transporting',
                  count: transportingCount,
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              Expanded(
                child: OverviewItem(
                  title: 'Device',
                  count: deviceCount,
                  icon: Icons.sensors_outlined,
                ),
              ),
              Expanded(
                child: OverviewItem(
                  title: 'Alert',
                  count: alertCount,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}