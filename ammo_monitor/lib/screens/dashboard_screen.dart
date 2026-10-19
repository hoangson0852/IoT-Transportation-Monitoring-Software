import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import '../models/transport_data.dart';
import '../services/firestore_service.dart';
import '../services/websocket_service.dart';
import '../widgets/dqm_badge_widget.dart';
import '../widgets/prediction_trend_widget.dart';
import '../widgets/qos_monitor_widget.dart';
import '../core/constants/app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Stream<List<TransportData>> _devicesStream = FirestoreService()
      .streamAllVehicles();

  Timer? _pollingTimer;
  StreamSubscription? _wsTelemetrySub;
  StreamSubscription? _wsAlertsSub;

  Map<String, dynamic> _serverHealth = {
    'status': 'connecting',
    'service': 'local-iot-backend',
    'database': 'sqlite',
  };
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _systemLogs = [];

  // WebSocket real-time prediction and DQM cache
  Map<String, dynamic>? _latestPrediction;
  Map<String, dynamic>? _latestDqm;
  Map<String, dynamic> _wsNodeData = {};

  // Vai trò phân quyền và bộ lọc nâng cấp Tuần 11
  String _currentRole = 'admin'; // 'admin', 'operator', 'viewer'
  String _alertFilter = 'unresolved'; // 'all', 'unresolved', 'resolved'
  List<TransportData> _latestDevices = [];

  @override
  void initState() {
    super.initState();
    _pollData();

    // 1. WebSocket Stream Subscription (Push < 500ms)
    WebSocketService().connect(baseUrl: AppConfig.baseUrl.replaceAll("http", "ws"));
    _wsTelemetrySub = WebSocketService().telemetryStream.listen((msg) {
      if (msg.containsKey('data') && msg['data'] is Map<String, dynamic>) {
        final nodeData = msg['data'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _wsNodeData = nodeData;
            if (nodeData.containsKey('prediction')) {
              _latestPrediction = nodeData['prediction'] as Map<String, dynamic>?;
            }
            if (nodeData.containsKey('dqm')) {
              _latestDqm = nodeData['dqm'] as Map<String, dynamic>?;
            }
            _serverHealth['status'] = 'ok';
          });
        }
      }
    });

    _wsAlertsSub = WebSocketService().alertsStream.listen((msg) {
      _pollData();
    });

    // 2. Poll endpoints every 4 seconds to fetch server health, alerts, and logs (HTTP Fallback)
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _pollData();
    });
  }

  @override
  void dispose() {
    _wsTelemetrySub?.cancel();
    _wsAlertsSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollData() async {
    try {
      final health = await FirestoreService().checkServerHealth();

      bool? resolvedParam;
      if (_alertFilter == 'unresolved') resolvedParam = false;
      if (_alertFilter == 'resolved') resolvedParam = true;

      final alerts = await FirestoreService().fetchAlerts(
        limit: 10,
        resolved: resolvedParam,
      );
      final logs = await FirestoreService().fetchSystemLogs(limit: 10);
      if (mounted) {
        setState(() {
          _serverHealth = health;
          _alerts = alerts;
          _systemLogs = logs;
        });
      }
    } catch (e) {
      print('Dashboard polling error: $e');
    }
  }

  Future<void> _resolveAlertItem(int alertId) async {
    final success = await FirestoreService().resolveAlert(alertId);
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã xử lý cảnh báo ID $alertId.')));
      _pollData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Không thể xử lý cảnh báo.')),
      );
    }
  }

  void _downloadCsv(String filename, String csvContent) {
    try {
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print("Download CSV error: $e");
    }
  }

  void _exportAlertsCsv() {
    if (_alerts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có cảnh báo để xuất.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(
      "ID,Vehicle ID,Alert Type,Severity,Message,Resolved,Created At",
    );
    for (final alert in _alerts) {
      final id = alert['id'] ?? '';
      final vehicleId = alert['vehicle_id'] ?? '';
      final alertType = alert['alert_type'] ?? '';
      final severity = alert['severity'] ?? '';
      final message = (alert['message'] ?? '').toString().replaceAll('"', '""');
      final resolved = alert['resolved'] == true ? 'Yes' : 'No';
      final createdAt = alert['created_at'] ?? '';
      buffer.writeln(
        '$id,$vehicleId,$alertType,$severity,"$message",$resolved,$createdAt',
      );
    }

    _downloadCsv("alerts_export.csv", buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang tải về file alerts_export.csv...')),
    );
  }

  void _exportNodesCsv() {
    if (_latestDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu thiết bị để xuất.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(
      "Vehicle ID,Status,Battery,RSSI,SNR,Temperature,Humidity,Vibration,Lid Status,Prediction,Latitude,Longitude,Last Updated",
    );
    for (final d in _latestDevices) {
      final vehicleId = d.vehicleId;
      final status = d.statusText;
      final battery = d.battery.toStringAsFixed(0);
      final rssi = d.gatewayRssi;
      final snr = d.gatewaySnr;
      final temp = d.temperature.toStringAsFixed(1);
      final hum = d.humidity.toStringAsFixed(0);
      final vib = d.accelMagnitude.toStringAsFixed(2);
      final lid = d.tamper == 1 ? 'OPEN' : 'SECURE';
      final pred = d.mlPredictionDisplay;
      final lat = d.latitude;
      final lon = d.longitude;
      final lastUpdated = d.lastUpdated.toDate().toIso8601String();
      buffer.writeln(
        '$vehicleId,$status,$battery,$rssi,$snr,$temp,$hum,$vib,$lid,$pred,$lat,$lon,$lastUpdated',
      );
    }

    _downloadCsv("nodes_status_export.csv", buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang tải về file nodes_status_export.csv...'),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _alertFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1C70D1),
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _alertFilter = value;
          });
          _pollData();
        }
      },
    );
  }

  void _exportVehicleCsv(String vehicleId) async {
    if (_currentRole == 'viewer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quyền Viewer: Không được phép xuất báo cáo.'),
        ),
      );
      return;
    }
    final url = '${AppConfig.baseUrl}/api/reports/export/$vehicleId';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở link tải báo cáo.')),
        );
      }
    } catch (e) {
      print('Failed to trigger export: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: StreamBuilder<List<TransportData>>(
        stream: _devicesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final devices = snapshot.data!;
          _latestDevices = devices; // Lưu để xuất CSV
          final total = devices.length;
          final active = devices.where((d) => d.isOnline).length;
          final offline = total - active;
          final critical = devices.where((d) => d.isCritical).length;

          // Tính dung lượng pin trung bình
          double avgBattery = 0.0;
          if (devices.isNotEmpty) {
            avgBattery =
                devices.map((d) => d.battery).reduce((a, b) => a + b) /
                devices.length;
          }
          final unresolvedAlertsCount = _alerts.length;

          // Alert trends data
          final List<double> alertChart = [
            5,
            12,
            8,
            14,
            10,
            _alerts.length.toDouble(),
          ];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiêu đề Dashboard kết hợp Dropdown phân quyền
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Dashboard",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D2533),
                              ),
                            ),
                            const Text(
                              "Hệ thống giám sát vận chuyển đạn dược thời gian thực",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentRole,
                            items: const [
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text(
                                  'Admin (Quản trị)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'operator',
                                child: Text(
                                  'Operator (Vận hành)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'viewer',
                                child: Text(
                                  'Viewer (Giám sát)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _currentRole = val;
                                });
                                _pollData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 1. HEALTH STATUS BAR
                  _buildHealthStatusBar(),

                  const SizedBox(height: 12),

                  // 1b. DQM & PREDICTIVE DEW POINT WIDGET
                  PredictionTrendWidget(
                    predictionData: _latestPrediction ?? {
                      'dew_point_current': 18.5,
                      'temp_margin': 6.5,
                      'condensation_risk': false,
                      'risk_level': 'NORMAL',
                      'warning_message': 'Điều kiện môi trường an toàn.',
                      'forecast_2h': {
                        'temp_2h': 25.0,
                        'humidity_2h': 65.0,
                        'dew_point_2h': 18.0
                      }
                    },
                    currentTemp: (_wsNodeData['temperature'] as num?)?.toDouble() ?? (devices.isNotEmpty ? devices.first.temperature : 25.0),
                    currentHumidity: (_wsNodeData['humidity'] as num?)?.toDouble() ?? (devices.isNotEmpty ? devices.first.humidity : 60.0),
                  ),

                  const SizedBox(height: 12),

                  // 1c. QOS MONITOR WIDGET
                  QosMonitorWidget(
                    battery: (_wsNodeData['battery'] as num?)?.toDouble() ?? (devices.isNotEmpty ? devices.first.battery : 95.0),
                    rssi: (_wsNodeData['gateway_rssi'] as num?)?.toInt() ?? (devices.isNotEmpty ? devices.first.gatewayRssi : -75),
                    snr: (_wsNodeData['gateway_snr'] as num?)?.toDouble() ?? (devices.isNotEmpty ? (devices.first.gatewaySnr as num).toDouble() : 9.5),
                    packetLossRatePct: 0.0,
                    lastUpdated: _wsNodeData['last_updated']?.toString() ?? (devices.isNotEmpty ? devices.first.lastUpdated.toDate().toIso8601String() : "Just now"),
                  ),

                  const SizedBox(height: 16),

                  // 2. OVERVIEW CARDS
                  _sectionCard(
                    title: "System Overview",
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _overviewItem(
                                Icons.devices_other_rounded,
                                "Tổng thiết bị",
                                "$total",
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _overviewItem(
                                Icons.play_circle_outline,
                                "Đang hoạt động",
                                "$active",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _overviewItem(
                                Icons.cloud_off_rounded,
                                "Mất kết nối",
                                "$offline",
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _overviewItem(
                                Icons.warning_amber_rounded,
                                "Cảnh báo",
                                "$critical",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _overviewItem(
                                Icons.battery_charging_full_rounded,
                                "Pin trung bình",
                                "${avgBattery.toStringAsFixed(1)}%",
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _overviewItem(
                                Icons.notification_important_rounded,
                                "Cảnh báo bộ lọc",
                                "$unresolvedAlertsCount",
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. DONUT STATUS CHART & TREND CHART (Flex row)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _sectionCard(
                          title: "Device Status",
                          child: SizedBox(
                            height: 150,
                            child: CustomPaint(
                              painter: DonutPainter(
                                activeCount: active,
                                offlineCount: offline,
                                criticalCount: critical,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _sectionCard(
                          title: "Alert Trends",
                          child: SizedBox(
                            height: 150,
                            child: CustomPaint(
                              painter: LineChartPainter(alertChart),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. ACTIVE SECURITY ALERTS LIST (GET /api/alerts)
                  _sectionCard(
                    title: "Alert Center (${_alerts.length})",
                    headerRight: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterChip("Chưa xử lý", "unresolved"),
                        const SizedBox(width: 4),
                        _buildFilterChip("Đã xử lý", "resolved"),
                        const SizedBox(width: 4),
                        _buildFilterChip("Tất cả", "all"),
                        if (_currentRole == 'admin') ...[
                          const SizedBox(width: 8),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.download_rounded,
                              size: 20,
                              color: Color(0xFF1C70D1),
                            ),
                            tooltip: "Xuất Alerts CSV",
                            onPressed: _exportAlertsCsv,
                          ),
                        ],
                      ],
                    ),
                    child: _buildAlertsList(),
                  ),

                  const SizedBox(height: 16),

                  // 5. EXPORT CSV REPORTS (GET /api/reports/export/<id>)
                  _sectionCard(
                    title: "Xuất báo cáo hành trình (CSV)",
                    headerRight: _currentRole == 'admin'
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20A464),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: _exportNodesCsv,
                            icon: const Icon(Icons.download_rounded, size: 12),
                            label: const Text("Tải trạng thái tất cả xe"),
                          )
                        : null,
                    child: _buildExportCsvSection(devices),
                  ),

                  const SizedBox(height: 16),

                  // 6. SYSTEM ACTIVITY LOGS (GET /api/system_logs)
                  _sectionCard(
                    title: "Nhật ký hệ thống Local Server",
                    child: _buildSystemLogsTerminal(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthStatusBar() {
    final isOnline = _serverHealth['status'] == 'ok';
    final bgColor = isOnline
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);
    final borderColor = isOnline
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFEF9A9A);
    final textColor = isOnline
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.check_circle_rounded : Icons.offline_share_rounded,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Local Server: ${isOnline ? 'ONLINE (Đang kết nối)' : 'OFFLINE (Mất kết nối)'}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  "Database: SQLite | Cổng: 5001 | Dữ liệu: Local Offline",
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    if (_alerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: const Column(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.green, size: 36),
            SizedBox(height: 8),
            Text(
              "Hệ thống an toàn",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              "Không phát hiện cảnh báo nguy hiểm trong CSDL SQLite.",
              style: TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _alerts.map((alert) {
        final alertType = alert['alert_type'] ?? 'sensor_abnormal';
        final severity = alert['severity'] ?? 'medium';
        final message = alert['message'] ?? '';
        final vehicleId = alert['vehicle_id'] ?? 'Unknown';
        final createdAt = alert['created_at'] ?? '';
        final isResolved = alert['resolved'] == true;

        String timeStr = '';
        if (createdAt.isNotEmpty) {
          try {
            final parsed = DateTime.parse(createdAt.toString()).toLocal();
            timeStr =
                "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}:${parsed.second.toString().padLeft(2, '0')}";
          } catch (_) {
            timeStr = createdAt;
          }
        }

        IconData iconData = Icons.warning_amber_rounded;
        Color severityColor = Colors.orange;
        if (severity == 'critical') {
          iconData = Icons.gpp_bad_rounded;
          severityColor = Colors.red;
        } else if (alertType == 'route_deviation') {
          iconData = Icons.navigation_rounded;
          severityColor = Colors.deepOrange;
        } else if (alertType == 'low_battery') {
          iconData = Icons.battery_alert_rounded;
          severityColor = Colors.redAccent;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isResolved ? Colors.grey.shade100 : Colors.grey.shade50,
            border: Border.all(
              color: isResolved ? Colors.grey.shade200 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isResolved
                      ? Colors.grey.shade200
                      : severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconData,
                  color: isResolved ? Colors.grey : severityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Xe: $vehicleId",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isResolved
                                ? Colors.grey
                                : const Color(0xFF1D2533),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isResolved
                                ? Colors.grey.shade200
                                : severityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isResolved ? "RESOLVED" : severity.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isResolved ? Colors.grey : severityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        color: isResolved ? Colors.grey : Colors.black87,
                        decoration: isResolved
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isResolved)
                    const Text(
                      "Đã xử lý",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (_currentRole == 'admin' ||
                      _currentRole == 'operator')
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      tooltip: "Đánh dấu đã xử lý",
                      onPressed: () => _resolveAlertItem(alert['id']),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExportCsvSection(List<TransportData> devices) {
    if (devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          "Không có phương tiện nào trực tuyến để xuất dữ liệu.",
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    return Column(
      children: devices.map((d) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_rounded,
                    color: d.isOnline ? const Color(0xFF1C70D1) : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.vehicleId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1D2533),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DqmBadgeWidget(
                    statusBadge: _latestDqm?['dqm_badge'] as String? ?? "RELIABLE",
                    dqmScore: (_latestDqm?['dqm_score'] as num?)?.toDouble() ?? 100.0,
                    isOutlierDetected: _latestDqm?['is_outlier_detected'] as bool? ?? false,
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C70D1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _exportVehicleCsv(d.vehicleId),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text("Tải báo cáo CSV"),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSystemLogsTerminal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Tailind Slate 900
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "SQLite Logging Terminal",
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          const SizedBox(height: 4),
          _systemLogs.isEmpty
              ? const Text(
                  "Waiting for system logs...",
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _systemLogs.map((log) {
                    String timeStr = '';
                    if (log['created_at'] != null) {
                      try {
                        final parsed = DateTime.parse(
                          log['created_at'].toString(),
                        ).toLocal();
                        timeStr =
                            "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}:${parsed.second.toString().padLeft(2, '0')}";
                      } catch (_) {
                        timeStr = log['created_at']
                            .toString()
                            .split('T')
                            .last
                            .substring(0, 8);
                      }
                    }
                    final level = log['level'] ?? 'INFO';
                    final message = log['message'] ?? '';

                    Color logColor = Colors.greenAccent;
                    if (level == 'SECURITY') {
                      logColor = Colors.redAccent;
                    } else if (level == 'WARN') {
                      logColor = Colors.orangeAccent;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "[$timeStr] [$level] $message",
                        style: TextStyle(
                          color: logColor,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? headerRight,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1D2533),
                ),
              ),
              ?headerRight,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _overviewItem(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D2533),
                  ),
                ),
              ],
            ),
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
  final int activeCount;
  final int offlineCount;
  final int criticalCount;

  DonutPainter({
    required this.activeCount,
    required this.offlineCount,
    required this.criticalCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double total = (activeCount + offlineCount + criticalCount).toDouble();
    if (total == 0) total = 1;

    const stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.height - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -1.57;

    final paints = [
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.green.shade400,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.grey.shade300,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.red.shade400,
    ];

    double currentAngle = startAngle;

    for (final entry in [activeCount, offlineCount, criticalCount]) {
      final sweep = 6.283 * (entry / total);
      if (sweep > 0) {
        canvas.drawArc(rect, currentAngle, sweep, false, paints[0]);
      }
      paints.removeAt(0);
      currentAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class LineChartPainter extends CustomPainter {
  final List<double> points;

  LineChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = points.reduce((a, b) => a > b ? a : b).clamp(1.0, 999.0);

    final paintLine = Paint()
      ..color = const Color(0xFF1C70D1)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final paintPoint = Paint()..color = const Color(0xFF1C70D1);

    const padding = 12.0;
    final step = (size.width - padding * 2) / (points.length - 1);

    final path = Path();

    for (int i = 0; i < points.length; i++) {
      final x = padding + step * i;
      final y =
          size.height -
          padding -
          (points[i] / maxVal) * (size.height - padding * 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3, paintPoint);
    }

    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(_) => true;
}
