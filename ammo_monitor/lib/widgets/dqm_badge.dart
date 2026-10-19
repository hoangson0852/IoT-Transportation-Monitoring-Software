import 'package:flutter/material.dart';

class DQMBadge extends StatelessWidget {
  final double dqmScore;
  final String statusBadge;

  const DQMBadge({
    super.key,
    required this.dqmScore,
    required this.statusBadge,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (dqmScore >= 90.0) {
      badgeColor = Colors.green;
      badgeText = "DQM: Tin cậy (${dqmScore.toInt()}%)";
      badgeIcon = Icons.verified_user_rounded;
    } else if (dqmScore >= 66.0) {
      badgeColor = Colors.orange;
      badgeText = "DQM: Đã lọc nhiễu (${dqmScore.toInt()}%)";
      badgeIcon = Icons.filter_alt_rounded;
    } else {
      badgeColor = Colors.red;
      badgeText = "DQM: Nhiễu hỏng (${dqmScore.toInt()}%)";
      badgeIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
