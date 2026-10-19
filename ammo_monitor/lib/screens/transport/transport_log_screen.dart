import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

enum LogFilter {
  all,
  normal,
  outOfRoute,
}

class TransportLogScreen extends StatefulWidget {
  final String vehicleId;

  const TransportLogScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  State<TransportLogScreen> createState() => _TransportLogScreenState();
}

class _TransportLogScreenState extends State<TransportLogScreen> {
  LogFilter selectedFilter = LogFilter.all;

  List<_TransportLogItem> _applyFilter(List<_TransportLogItem> logs) {
    switch (selectedFilter) {
      case LogFilter.normal:
        return logs.where((log) => !log.isOutOfRoute).toList();
      case LogFilter.outOfRoute:
        return logs.where((log) => log.isOutOfRoute).toList();
      case LogFilter.all:
        return logs;
    }
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
        title: Text(
          'Lịch sử ${widget.vehicleId}',
          style: const TextStyle(
            color: Color(0xFF1D2533),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService().streamVehicleLogs(widget.vehicleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Không tải được lịch sử',
              message: snapshot.error.toString(),
            );
          }

          final list = snapshot.data ?? [];

          final logs = list.map((data) {
            return _TransportLogItem.fromMap(data);
          }).toList();

          if (logs.isEmpty) {
            return const _MessageState(
              icon: Icons.history_rounded,
              title: 'Chưa có dữ liệu lịch sử',
              message:
                  'Khi xe bắt đầu được giám sát, dữ liệu vận chuyển sẽ được lưu tại đây.',
            );
          }

          final filteredLogs = _applyFilter(logs);
          final summary = _LogSummary.fromLogs(logs);

          return Column(
            children: [
              _HistorySummary(
                summary: summary,
              ),

              const SizedBox(height: 10),

              _FilterBar(
                selectedFilter: selectedFilter,
                totalCount: logs.length,
                normalCount: summary.normalCount,
                outOfRouteCount: summary.outOfRouteCount,
                onChanged: (filter) {
                  setState(() => selectedFilter = filter);
                },
              ),

              const SizedBox(height: 8),

              Expanded(
                child: filteredLogs.isEmpty
                    ? const _MessageState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Không có dữ liệu phù hợp',
                        message:
                            'Thử đổi bộ lọc để xem các bản ghi lịch sử khác.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];

                          return _HistoryLogCard(
                            log: log,
                            onTap: () {
                              _showLogDetail(context, log);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogDetail(BuildContext context, _TransportLogItem log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _LogDetailSheet(log: log);
      },
    );
  }
}

class _TransportLogItem {
  final String vehicleId;
  final String transportId;
  final double distance;
  final String prediction;
  final double latitude;
  final double longitude;
  final double speed;
  final double acceleration;
  final double temperature;
  final double humidity;
  final double lightLevel;
  final double accelMagnitude;
  final double gatewayRssi;
  final double gatewaySnr;
  final String rfAnomalyState;
  final String knnPrediction;
  final double anomalyFlag;
  final double tamper;
  final Timestamp? timestamp;

  const _TransportLogItem({
    required this.vehicleId,
    required this.transportId,
    required this.distance,
    required this.prediction,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.acceleration,
    required this.temperature,
    required this.humidity,
    required this.lightLevel,
    required this.accelMagnitude,
    required this.gatewayRssi,
    required this.gatewaySnr,
    required this.rfAnomalyState,
    required this.knnPrediction,
    required this.anomalyFlag,
    required this.tamper,
    required this.timestamp,
  });

  factory _TransportLogItem.fromMap(Map<String, dynamic> data) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    String toText(dynamic value, String fallback) {
      if (value == null) return fallback;
      return value.toString();
    }

    Timestamp? parseTs(dynamic val) {
      if (val is Timestamp) return val;
      if (val is String && val.isNotEmpty) {
        try {
          return Timestamp.fromDate(DateTime.parse(val));
        } catch (_) {}
      }
      return null;
    }

    return _TransportLogItem(
      vehicleId: toText(data['vehicle_id'] ?? data['node_id'], ''),
      transportId: toText(data['transport_id'] ?? data['vehicle_id'], ''),
      distance: toDouble(data['distance'] ?? data['ml_score']),
      prediction: toText(data['prediction'] ?? data['ml_prediction'], 'NORMAL'),
      latitude: toDouble(data['lat'] ?? data['latitude']),
      longitude: toDouble(data['lon'] ?? data['longitude']),
      speed: toDouble(data['speed'] ?? 15.2),
      acceleration: toDouble(data['acceleration']),
      temperature: toDouble(data['temperature']),
      humidity: toDouble(data['humidity']),
      lightLevel: toDouble(data['light_level'] ?? data['light']),
      accelMagnitude: toDouble(data['accel_magnitude'] ?? data['acceleration']),
      gatewayRssi: toDouble(data['gateway_rssi'] ?? data['rssi']),
      gatewaySnr: toDouble(data['gateway_snr'] ?? data['snr']),
      rfAnomalyState: toText(data['rf_anomaly_state'], 'NORMAL'),
      knnPrediction: toText(data['knn_prediction'], 'NORMAL'),
      anomalyFlag: toDouble(data['anomaly_flag']),
      tamper: toDouble(data['tamper']),
      timestamp: parseTs(data['timestamp'] ?? data['created_at']),
    );
  }

  bool get isOutOfRoute => prediction == 'OUT_OF_ROUTE';

  String get predictionDisplay {
    if (isOutOfRoute) return 'Lệch tuyến';
    return 'Đúng tuyến';
  }

  Color get statusColor {
    if (isOutOfRoute) return const Color(0xFFE53935);
    return const Color(0xFF20A464);
  }

  IconData get statusIcon {
    if (isOutOfRoute) return Icons.warning_amber_rounded;
    return Icons.check_circle_rounded;
  }
}

class _LogSummary {
  final int totalCount;
  final int normalCount;
  final int outOfRouteCount;
  final double avgDistance;
  final double maxDistance;

  const _LogSummary({
    required this.totalCount,
    required this.normalCount,
    required this.outOfRouteCount,
    required this.avgDistance,
    required this.maxDistance,
  });

  factory _LogSummary.fromLogs(List<_TransportLogItem> logs) {
    if (logs.isEmpty) {
      return const _LogSummary(
        totalCount: 0,
        normalCount: 0,
        outOfRouteCount: 0,
        avgDistance: 0,
        maxDistance: 0,
      );
    }

    final total = logs.length;
    final outOfRoute = logs.where((log) => log.isOutOfRoute).length;
    final normal = total - outOfRoute;

    final totalDistance = logs.fold<double>(
      0,
      (sum, log) => sum + log.distance,
    );

    final maxDistance = logs.fold<double>(
      0,
      (max, log) => log.distance > max ? log.distance : max,
    );

    return _LogSummary(
      totalCount: total,
      normalCount: normal,
      outOfRouteCount: outOfRoute,
      avgDistance: totalDistance / total,
      maxDistance: maxDistance,
    );
  }
}

class _HistorySummary extends StatelessWidget {
  final _LogSummary summary;

  const _HistorySummary({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1C70D1),
            Color(0xFF4BA3FF),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C70D1).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Tổng quan lịch sử vận chuyển',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Bản ghi',
                  value: '${summary.totalCount}',
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'Lệch tuyến',
                  value: '${summary.outOfRouteCount}',
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'TB lệch',
                  value: '${summary.avgDistance.toStringAsFixed(1)}m',
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'Max',
                  value: '${summary.maxDistance.toStringAsFixed(1)}m',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final LogFilter selectedFilter;
  final int totalCount;
  final int normalCount;
  final int outOfRouteCount;
  final ValueChanged<LogFilter> onChanged;

  const _FilterBar({
    required this.selectedFilter,
    required this.totalCount,
    required this.normalCount,
    required this.outOfRouteCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _FilterChipItem(
            label: 'Tất cả',
            count: totalCount,
            selected: selectedFilter == LogFilter.all,
            onTap: () => onChanged(LogFilter.all),
          ),
          _FilterChipItem(
            label: 'Đúng tuyến',
            count: normalCount,
            selected: selectedFilter == LogFilter.normal,
            onTap: () => onChanged(LogFilter.normal),
          ),
          _FilterChipItem(
            label: 'Lệch tuyến',
            count: outOfRouteCount,
            selected: selectedFilter == LogFilter.outOfRoute,
            onTap: () => onChanged(LogFilter.outOfRoute),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        selected ? const Color(0xFF1C70D1) : Colors.white;
    final textColor = selected ? Colors.white : const Color(0xFF1D2533);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1C70D1)
                    : const Color(0xFFE7ECF4),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$label ($count)',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryLogCard extends StatelessWidget {
  final _TransportLogItem log;
  final VoidCallback onTap;

  const _HistoryLogCard({
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time = _formatTimestamp(log.timestamp);

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
              color: log.isOutOfRoute
                  ? const Color(0xFFFFD9D9)
                  : const Color(0xFFE7ECF4),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: log.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  log.statusIcon,
                  color: log.statusColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            log.predictionDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: log.statusColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(
                          label: 'Lệch ${log.distance.toStringAsFixed(1)} m',
                          color: log.statusColor,
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'GPS: ${log.latitude.toStringAsFixed(6)}, ${log.longitude.toStringAsFixed(6)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        _MiniInfo(
                          icon: Icons.speed_rounded,
                          text: '${log.speed.toStringAsFixed(1)} m/s',
                        ),
                        const SizedBox(width: 10),
                        _MiniInfo(
                          icon: Icons.thermostat_rounded,
                          text: '${log.temperature.toStringAsFixed(1)}°C',
                        ),
                        const SizedBox(width: 10),
                        _MiniInfo(
                          icon: Icons.water_drop_outlined,
                          text: '${log.humidity.toStringAsFixed(0)}%',
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
                    time,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF8A94A6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8A94A6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';

    final dt = timestamp.toDate();

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');

    return '$hour:$minute\n$day/$month';
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Color(0xFF8A94A6),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  final _TransportLogItem log;

  const _LogDetailSheet({
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final time = _formatFullTimestamp(log.timestamp);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7ECF4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: log.statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      log.statusIcon,
                      color: log.statusColor,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.predictionDisplay,
                          style: TextStyle(
                            color: log.statusColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _DetailSection(
                title: 'Thông tin tuyến đường',
                items: [
                  _DetailItem(
                    label: 'Mã xe',
                    value: log.vehicleId.isEmpty ? '--' : log.vehicleId,
                  ),
                  _DetailItem(
                    label: 'Mã vận chuyển',
                    value: log.transportId.isEmpty ? '--' : log.transportId,
                  ),
                  _DetailItem(
                    label: 'Độ lệch',
                    value: '${log.distance.toStringAsFixed(2)} m',
                  ),
                  _DetailItem(
                    label: 'Trạng thái',
                    value: log.predictionDisplay,
                  ),
                  _DetailItem(
                    label: 'GPS',
                    value:
                        '${log.latitude.toStringAsFixed(7)}, ${log.longitude.toStringAsFixed(7)}',
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _DetailSection(
                title: 'Dữ liệu chuyển động',
                items: [
                  _DetailItem(
                    label: 'Tốc độ',
                    value: '${log.speed.toStringAsFixed(2)} m/s',
                  ),
                  _DetailItem(
                    label: 'Gia tốc',
                    value: '${log.acceleration.toStringAsFixed(3)} m/s²',
                  ),
                  _DetailItem(
                    label: 'Rung động',
                    value: '${log.accelMagnitude.toStringAsFixed(2)} g',
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _DetailSection(
                title: 'Dữ liệu cảm biến',
                items: [
                  _DetailItem(
                    label: 'Nhiệt độ',
                    value: '${log.temperature.toStringAsFixed(1)} °C',
                  ),
                  _DetailItem(
                    label: 'Độ ẩm',
                    value: '${log.humidity.toStringAsFixed(0)} %',
                  ),
                  _DetailItem(
                    label: 'Ánh sáng',
                    value: log.lightLevel.toStringAsFixed(0),
                  ),
                  _DetailItem(
                    label: 'Tamper',
                    value: log.tamper.toStringAsFixed(0),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _DetailSection(
                title: 'Dữ liệu gateway / AI',
                items: [
                  _DetailItem(
                    label: 'Gateway RSSI',
                    value: log.gatewayRssi.toStringAsFixed(0),
                  ),
                  _DetailItem(
                    label: 'Gateway SNR',
                    value: log.gatewaySnr.toStringAsFixed(0),
                  ),
                  _DetailItem(
                    label: 'RF anomaly',
                    value: log.rfAnomalyState,
                  ),
                  _DetailItem(
                    label: 'KNN prediction',
                    value: log.knnPrediction,
                  ),
                  _DetailItem(
                    label: 'Anomaly flag',
                    value: log.anomalyFlag.toStringAsFixed(0),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFullTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Không rõ thời gian';

    final dt = timestamp.toDate();

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();

    return '$hour:$minute:$second - $day/$month/$year';
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailItem> items;

  const _DetailSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE7ECF4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1D2533),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 116,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1D2533),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;

  const _DetailItem({
    required this.label,
    required this.value,
  });
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1C70D1),
                size: 36,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1D2533),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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