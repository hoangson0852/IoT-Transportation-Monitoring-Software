import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/transport_data.dart';
import '../transport/transport_detail_screen.dart';

import '../../services/firestore_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  bool _isRouteAlert(TransportData vehicle) {
    return vehicle.mlPrediction != "NORMAL";
  }

  bool _isSensorAlert(TransportData vehicle) {
    return vehicle.anomalyFlag == 1;
  }

  bool _isTamperAlert(TransportData vehicle) {
    return vehicle.tamper == 1;
  }

  bool _hasAnyAlert(TransportData vehicle) {
    return _isRouteAlert(vehicle) ||
        _isSensorAlert(vehicle) ||
        _isTamperAlert(vehicle);
  }

  List<String> _getAlertReasons(TransportData vehicle) {
    final reasons = <String>[];

    if (_isRouteAlert(vehicle)) {
      reasons.add(
        'Lệch tuyến ${vehicle.mlScore.toStringAsFixed(1)} m',
      );
    }

    if (_isSensorAlert(vehicle)) {
      reasons.add('Cảm biến bất thường');
    }

    if (_isTamperAlert(vehicle)) {
      reasons.add('Nắp hộp bị mở');
    }

    return reasons;
  }

  Stream<List<TransportData>> _alertVehiclesStream() {
    return FirestoreService().streamAllVehicles().map(
          (list) => list.where(_hasAnyAlert).toList(),
        );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Vừa cập nhật';

    final dt = timestamp.toDate();

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');

    return '$hour:$minute - $day/$month';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6F8FC),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1D2533),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF1D2533),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<TransportData>>(
        stream: _alertVehiclesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
            return const _EmptyNotificationState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vehicle = alerts[index];
              final reasons = _getAlertReasons(vehicle);

              return _NotificationAlertCard(
                vehicle: vehicle,
                reasons: reasons,
                timeText: _formatTime(vehicle.lastUpdated),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransportDetailScreen(data: vehicle),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationAlertCard extends StatelessWidget {
  final TransportData vehicle;
  final List<String> reasons;
  final String timeText;
  final VoidCallback onTap;

  const _NotificationAlertCard({
    required this.vehicle,
    required this.reasons,
    required this.timeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reasonText = reasons.join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD9D9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE53935),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xe ${vehicle.transportId} đang gặp nguy hiểm!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1D2533),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reasonText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vui lòng kiểm tra trạng thái xe và thiết bị ngay.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFF8A94A6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${vehicle.latitude.toStringAsFixed(6)}, ${vehicle.longitude.toStringAsFixed(6)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8A94A6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: Color(0xFF8A94A6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Danger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF1C70D1),
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Không có cảnh báo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1D2533),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Các thông báo lệch tuyến, cảm biến bất thường hoặc nắp hộp bị mở sẽ được hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}