import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/transport_data.dart';
import '../../services/firestore_service.dart';
import 'transport_log_screen.dart';

class TransportDetailScreen extends StatefulWidget {
  final TransportData data;

  const TransportDetailScreen({
    super.key,
    required this.data,
  });

  @override
  State<TransportDetailScreen> createState() => _TransportDetailScreenState();
}

class _TransportDetailScreenState extends State<TransportDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isDialogShowing = false;
  String? _lastAlertSignature;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ================= ALERT HELPERS =================
  bool _isRouteAlert(TransportData data) {
    return data.mlPrediction != "NORMAL";
  }

  bool _isSensorAlert(TransportData data) {
    return data.anomalyFlag == 1;
  }

  bool _isTamperAlert(TransportData data) {
    return data.tamper == 1;
  }

  bool _isLowBatteryAlert(TransportData data) {
    return data.isLowBattery;
  }

  List<String> _getAlertReasons(TransportData data) {
    final reasons = <String>[];

    if (_isRouteAlert(data)) {
      reasons.add(
        "Xe đang lệch tuyến ${data.mlScore.toStringAsFixed(1)} m",
      );
    }

    if (_isSensorAlert(data)) {
      reasons.add("Cảm biến phát hiện trạng thái bất thường");
    }

    if (_isTamperAlert(data)) {
      reasons.add("Nắp hộp thiết bị đang bị mở");
    }

    if (_isLowBatteryAlert(data)) {
      reasons.add("Pin thiết bị dưới 20% (${data.battery.toStringAsFixed(0)}%)");
    }

    return reasons;
  }

  String _getAlertSignature(TransportData data) {
    return [
      data.mlPrediction,
      data.mlScore.toStringAsFixed(1),
      data.anomalyFlag,
      data.tamper,
      data.isLowBattery ? "LOW" : "OK",
    ].join('|');
  }

  void _triggerEmergencyAlert(TransportData currentData) {
    final reasons = _getAlertReasons(currentData);

    if (reasons.isEmpty) {
      _lastAlertSignature = null;
      return;
    }

    final signature = _getAlertSignature(currentData);

    if (_isDialogShowing || _lastAlertSignature == signature) {
      return;
    }

    _isDialogShowing = true;
    _lastAlertSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Cảnh báo nguy hiểm",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Xe ${currentData.transportId} đang gặp sự cố:",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2533),
                  ),
                ),
                const SizedBox(height: 12),
                ...reasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_rounded,
                          color: Color(0xFFE53935),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              color: Color(0xFF1D2533),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Vui lòng kiểm tra vị trí và trạng thái thiết bị ngay.",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _isDialogShowing = false;
                  Navigator.pop(context);
                },
                child: const Text(
                  "ĐÃ HIỂU",
                  style: TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ).then((_) {
        _isDialogShowing = false;
      });
    });
  }

  // ================= ROUTE PROGRESS HELPERS =================
  double _distanceBetween(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;

    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  int _nearestRouteIndex({
    required LatLng vehiclePoint,
    required List<LatLng> routePoints,
  }) {
    if (routePoints.isEmpty) return 0;

    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var i = 0; i < routePoints.length; i++) {
      final distance = _distanceBetween(vehiclePoint, routePoints[i]);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  List<LatLng> _completedRoutePoints({
    required LatLng vehiclePoint,
    required List<LatLng> routePoints,
  }) {
    if (routePoints.length < 2) return [];

    final nearestIndex = _nearestRouteIndex(
      vehiclePoint: vehiclePoint,
      routePoints: routePoints,
    );

    if (nearestIndex <= 0) {
      return [
        routePoints.first,
        vehiclePoint,
      ];
    }

    return [
      ...routePoints.take(nearestIndex + 1),
      vehiclePoint,
    ];
  }

  List<LatLng> _remainingRoutePoints({
    required LatLng vehiclePoint,
    required List<LatLng> routePoints,
  }) {
    if (routePoints.length < 2) return routePoints;

    final nearestIndex = _nearestRouteIndex(
      vehiclePoint: vehiclePoint,
      routePoints: routePoints,
    );

    if (nearestIndex >= routePoints.length - 1) {
      return [vehiclePoint];
    }

    return [
      vehiclePoint,
      ...routePoints.skip(nearestIndex + 1),
    ];
  }

  LatLng _getInitialCenter({
    required List<LatLng> points,
    required LatLng? currentPosition,
  }) {
    if (currentPosition != null) return currentPosition;
    if (points.isNotEmpty) return points.first;

    return const LatLng(10.8047, 106.7016);
  }

  // ================= MAP MODAL =================
  void _showRouteModal(
    BuildContext context,
    String vehicleId,
    List<LatLng> points,
    LatLng? currentPosition,
  ) {
    final completedPoints = currentPosition == null
        ? <LatLng>[]
        : _completedRoutePoints(
            vehiclePoint: currentPosition,
            routePoints: points,
          );

    final remainingPoints = currentPosition == null
        ? points
        : _remainingRoutePoints(
            vehiclePoint: currentPosition,
            routePoints: points,
          );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Lộ trình: $vehicleId",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    _RouteLegendItem(
                      color: const Color(0xFF8A94A6).withOpacity(0.55),
                      label: 'Đã đi qua',
                    ),
                    const SizedBox(width: 16),
                    _RouteLegendItem(
                      color: const Color(0xFF1C70D1),
                      label: 'Còn lại',
                    ),
                    const SizedBox(width: 16),
                    _RouteLegendItem(
                      color: const Color(0xFF20A464),
                      label: 'Bắt đầu',
                    ),
                    const Spacer(),
                    if (currentPosition != null)
                      const Text(
                        'GPS realtime',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _getInitialCenter(
                      points: points,
                      currentPosition: currentPosition,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'vn.edu.hcmut.ammomonitor',
                    ),
                    if (points.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          if (completedPoints.length >= 2)
                            Polyline(
                              points: completedPoints,
                              color: const Color(0xFF8A94A6).withOpacity(0.45),
                              strokeWidth: 5.0,
                            ),
                          if (remainingPoints.length >= 2)
                            Polyline(
                              points: remainingPoints,
                              color: const Color(0xFF1C70D1).withOpacity(0.95),
                              strokeWidth: 6.0,
                            ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (points.isNotEmpty)
                          Marker(
                            point: points.first,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF20A464),
                              size: 36,
                            ),
                          ),
                        if (points.isNotEmpty)
                          Marker(
                            point: points.last,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.flag,
                              color: Color(0xFFE53935),
                              size: 36,
                            ),
                          ),
                        if (currentPosition != null)
                          Marker(
                            point: currentPosition,
                            width: 62,
                            height: 62,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF1C70D1)
                                        .withOpacity(0.18),
                                  ),
                                ),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1C70D1),
                                  ),
                                  child: const Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TransportData>(
      stream: FirestoreService().streamVehicle(widget.data.vehicleId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final currentData = snapshot.data!;

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _triggerEmergencyAlert(currentData),
        );

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              "Chi tiết vận chuyển",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardStyle(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(currentData),
                  _divider(),
                  const Text(
                    "An ninh & Chẩn đoán",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _infoRow(
                    Icons.security,
                    "Tình trạng tuyến đường",
                    currentData.mlPrediction == "NORMAL"
                        ? "Đúng tuyến"
                        : "Lệch tuyến",
                    valueColor: currentData.mlPrediction == "NORMAL"
                        ? Colors.green
                        : Colors.red,
                  ),
                  _infoRow(
                    Icons.straighten,
                    "Độ lệch",
                    "${currentData.mlScore.toStringAsFixed(1)} m",
                  ),
                  _infoRow(
                    Icons.psychology_outlined,
                    "Trạng thái cảm biến",
                    currentData.anomalyFlag == 1 ? "Bất thường" : "Bình thường",
                    valueColor: currentData.anomalyFlag == 1
                        ? Colors.red
                        : Colors.green,
                  ),
                  _infoRow(
                    Icons.lock,
                    "Tình trạng nắp hộp",
                    currentData.tamper == 1 ? "BỊ MỞ" : "An toàn",
                    valueColor:
                        currentData.tamper == 1 ? Colors.red : Colors.green,
                  ),
                  _divider(),
                  const Text(
                    "Thông số cảm biến",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _infoRow(
                    Icons.thermostat,
                    "Nhiệt độ",
                    "${currentData.temperature}°C",
                  ),
                  _infoRow(
                    Icons.water_drop,
                    "Độ ẩm",
                    "${currentData.humidity}%",
                  ),
                  _infoRow(
                    Icons.battery_charging_full_rounded,
                    "Dung lượng pin",
                    "${currentData.battery.toStringAsFixed(0)}%",
                    valueColor: currentData.isLowBattery ? Colors.red : Colors.green,
                  ),
                  _infoRow(
                    Icons.vibration,
                    "Độ rung",
                    "${currentData.accelMagnitude.toStringAsFixed(2)} g",
                  ),
                  _divider(),
                  const Text(
                    "Thông số vô tuyến và vị trí",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _infoRow(
                    Icons.signal_cellular_alt,
                    "RSSI",
                    "${currentData.gatewayRssi} dBm",
                  ),
                  _infoRow(
                    Icons.radar,
                    "SNR",
                    "${currentData.gatewaySnr} dB",
                  ),
                  _infoRow(
                    Icons.location_on,
                    "Vị trí",
                    currentData.formattedGPS,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final pointsData = await FirestoreService()
                              .getActiveRoute(currentData.vehicleId);

                          List<LatLng> routePoints = [];
                          if (pointsData.isNotEmpty) {
                            routePoints = pointsData
                                .map(
                                  (p) => LatLng(
                                    p['lat']!,
                                    p['lng']!,
                                  ),
                                )
                                .toList();
                          } else {
                            // Lộ trình khuôn viên ĐH Bách Khoa cơ sở 2 (chuẩn Hình 6.17a)
                            routePoints = [
                              const LatLng(10.87965, 106.80785), // Điểm cờ đỏ (Đối diện Sân banh)
                              const LatLng(10.87830, 106.80685), // Dọc đường Tạ Quang Bửu (GYM A17)
                              const LatLng(10.87770, 106.80635), // Dọc Tạ Quang Bửu đến Nhà A14
                              const LatLng(10.87740, 106.80670), // Rẽ nội bộ qua A14 - A4
                              const LatLng(10.87720, 106.80650), // Đường nội bộ A4 - A3
                              const LatLng(10.87670, 106.80610), // Hướng về Nhà A2
                              const LatLng(10.87640, 106.80585), // Điểm dừng xe A2
                            ];
                          }

                          LatLng? currentPos;
                          if (currentData.latitude != 0 &&
                              currentData.longitude != 0) {
                            currentPos = LatLng(
                              currentData.latitude,
                              currentData.longitude,
                            );
                          } else {
                            currentPos = const LatLng(10.87640, 106.80585);
                          }

                          if (mounted) {
                            _showRouteModal(
                              context,
                              currentData.vehicleId,
                              routePoints,
                              currentPos,
                            );
                          }
                        } catch (e) {
                          debugPrint("Lỗi: $e");

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Lỗi tải lộ trình: $e"),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "XEM LỘ TRÌNH CHI TIẾT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransportLogScreen(
                              vehicleId: currentData.vehicleId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.history,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "XEM LỊCH SỬ DI CHUYỂN",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= WIDGET =================
  Widget _buildHeader(TransportData d) {
    return Row(
      children: [
        const Icon(
          Icons.local_shipping,
          color: Colors.blue,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            d.transportId,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          d.isOnline ? "ONLINE" : "OFFLINE",
          style: TextStyle(
            color: d.isOnline ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      color: Colors.grey.shade200,
      height: 30,
    );
  }

  BoxDecoration _cardStyle() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
        ),
      ],
    );
  }
}

class _RouteLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _RouteLegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}