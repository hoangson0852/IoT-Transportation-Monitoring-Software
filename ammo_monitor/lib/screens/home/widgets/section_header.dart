import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onViewAll;   // 🔥 thêm callback

  const SectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "$count",
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),

        const Spacer(),

        GestureDetector(
          onTap: onViewAll,
          child: const Icon(Icons.more_horiz, size: 22),
        ),
      ],
    );
  }
}
