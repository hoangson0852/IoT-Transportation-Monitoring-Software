import 'package:flutter/material.dart';

class DqmBadgeWidget extends StatelessWidget {
  final String statusBadge;
  final double dqmScore;
  final bool isOutlierDetected;

  const DqmBadgeWidget({
    super.key,
    required this.statusBadge,
    required this.dqmScore,
    this.isOutlierDetected = false,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData icon;
    String labelText;

    switch (statusBadge) {
      case "RELIABLE":
        badgeColor = Colors.green.shade700;
        icon = Icons.verified_user_rounded;
        labelText = "DQM: Tin cậy ($dqmScore%)";
        break;
      case "FILTERED_NOISE":
        badgeColor = Colors.orange.shade800;
        icon = Icons.filter_alt_rounded;
        labelText = "DQM: Đã lọc nhiễu ($dqmScore%)";
        break;
      case "UNRELIABLE":
      default:
        badgeColor = Colors.red.shade700;
        icon = Icons.gpp_bad_rounded;
        labelText = "DQM: Kém tin cậy ($dqmScore%)";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            labelText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (isOutlierDetected) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Nhiễu",
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          ]
        ],
      ),
    );
  }
}
