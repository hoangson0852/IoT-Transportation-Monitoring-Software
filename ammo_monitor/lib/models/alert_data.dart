import 'package:cloud_firestore/cloud_firestore.dart';

class AlertData {
  final bool isAlert;
  final String level;
  final String message;
  final Timestamp updatedAt;

  AlertData({
    required this.isAlert,
    required this.level,
    required this.message,
    required this.updatedAt,
  });

  factory AlertData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AlertData(
      isAlert: data['is_alert'] ?? false,
      level: data['level'] ?? 'normal',
      message: data['message'] ?? '',
      updatedAt: data['updated_at'],
    );
  }
}
