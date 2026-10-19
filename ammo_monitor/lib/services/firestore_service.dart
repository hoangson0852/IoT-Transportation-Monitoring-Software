import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transport_data.dart';
import '../models/mission_model.dart';
import '../core/constants/app_config.dart';

class FirestoreService {
  // ==================== VEHICLES ====================

  /// Fetch vehicles list từ Local Server
  Future<List<TransportData>> _fetchAllVehicles() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/vehicles');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['vehicles'] is List) {
          final list = data['vehicles'] as List;
          return list.map((item) => TransportData.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('FirestoreService: _fetchAllVehicles error: $e');
    }
    return [];
  }

  /// Stream toàn bộ xe (admin) - Polling mỗi 2 giây
  Stream<List<TransportData>> streamAllVehicles() async* {
    // Trả về dữ liệu ngay lập tức lần đầu tiên
    yield await _fetchAllVehicles();
    
    yield* Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) => _fetchAllVehicles());
  }

  /// Fetch chi tiết một xe từ Local Server
  Future<TransportData> _fetchVehicle(String vehicleId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/vehicles/$vehicleId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['vehicle'] != null) {
          return TransportData.fromJson(data['vehicle']);
        }
      }
    } catch (e) {
      print('FirestoreService: _fetchVehicle error: $e');
    }
    return TransportData(
      vehicleId: vehicleId,
      transportId: vehicleId,
      temperature: 0,
      humidity: 0,
      latitude: 0,
      longitude: 0,
      lightLevel: 0,
      accelMagnitude: 0,
      gatewayRssi: 0,
      gatewaySnr: 0,
      tamper: 0,
      anomalyFlag: 0,
      rfAnomaly: 'NORMAL',
      knnPrediction: 'NORMAL',
      mlPrediction: 'NORMAL',
      rfAnomalyState: 'NORMAL',
      mlScore: 0,
      online: false,
      battery: 100.0,
      lastUpdated: Timestamp.now(),
    );
  }

  /// Stream một xe theo ID - Polling mỗi 2 giây
  Stream<TransportData> streamVehicle(String vehicleId) async* {
    yield await _fetchVehicle(vehicleId);
    
    yield* Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) => _fetchVehicle(vehicleId));
  }

  /// Fetch nhật ký xe từ Local Server
  Future<List<Map<String, dynamic>>> _fetchVehicleLogs(String vehicleId, int limit) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/vehicles/$vehicleId/logs?limit=$limit');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['logs'] is List) {
          final list = data['logs'] as List;
          return list.map<Map<String, dynamic>>((item) {
            final map = Map<String, dynamic>.from(item);
            if (map['timestamp'] is String) {
              map['timestamp'] = Timestamp.fromDate(DateTime.parse(map['timestamp']));
            }
            return map;
          }).toList();
        }
      }
    } catch (e) {
      print('FirestoreService: _fetchVehicleLogs error: $e');
    }
    return [];
  }

  /// Stream nhật ký xe - Polling mỗi 5 giây
  Stream<List<Map<String, dynamic>>> streamVehicleLogs(String vehicleId, {int limit = 200}) async* {
    yield await _fetchVehicleLogs(vehicleId, limit);
    
    yield* Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _fetchVehicleLogs(vehicleId, limit));
  }

  // ==================== MISSIONS ====================

  /// Fetch all missions từ Local Server
  Future<List<MissionModel>> _fetchAllMissions() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/missions');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['missions'] is List) {
          final list = data['missions'] as List;
          return list.map((item) => MissionModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('FirestoreService: _fetchAllMissions error: $e');
    }
    return [];
  }

  /// Stream tất cả missions (admin) - Polling mỗi 5 giây
  Stream<List<MissionModel>> streamAllMissions() async* {
    yield await _fetchAllMissions();
    
    yield* Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _fetchAllMissions());
  }

  /// Fetch driver missions từ Local Server
  Future<List<MissionModel>> _fetchDriverMissions(String driverUid) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/missions/driver/$driverUid');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['missions'] is List) {
          final list = data['missions'] as List;
          return list.map((item) => MissionModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('FirestoreService: _fetchDriverMissions error: $e');
    }
    return [];
  }

  /// Stream missions của một driver - Polling mỗi 5 giây
  Stream<List<MissionModel>> streamDriverMissions(String driverUid) async* {
    yield await _fetchDriverMissions(driverUid);
    
    yield* Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _fetchDriverMissions(driverUid));
  }

  /// Tạo mission mới trên Local Server
  Future<String> createMission(MissionModel mission) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/missions');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vehicle_id': mission.vehicleId,
          'driver_uid': mission.driverUid,
          'cargo_description': mission.cargoDescription,
          'origin': mission.origin,
          'destination': mission.destination,
          'notes': mission.notes,
          'route_points': mission.routePoints
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['mission_id'] ?? '';
        }
      }
      throw Exception('Lỗi tạo nhiệm vụ trên server.');
    } catch (e) {
      throw Exception('Không tạo được lộ trình: $e');
    }
  }

  /// Cập nhật trạng thái mission
  Future<void> updateMissionStatus(
    String missionId,
    MissionStatus status, {
    Timestamp? timestamp,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/missions/$missionId');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status.name,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Không cập nhật được trạng thái.');
      }
    } catch (e) {
      print('FirestoreService: updateMissionStatus error: $e');
    }
  }

  // ==================== ACTIVE ROUTES ====================

  /// Lấy lộ trình của xe từ Local Server
  Future<List<Map<String, double>>> getActiveRoute(String vehicleId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/active_routes/$vehicleId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['points'] is List) {
          final list = data['points'] as List;
          return list.map<Map<String, double>>((p) => {
            'lat': (p['lat'] as num).toDouble(),
            'lng': (p['lng'] as num).toDouble(),
          }).toList();
        }
      }
    } catch (e) {
      print('FirestoreService: getActiveRoute error: $e');
    }
    return [];
  }

  // ==================== STATS ====================

  /// Đếm số xe đang online cục bộ
  Future<int> countOnlineVehicles() async {
    final list = await _fetchAllVehicles();
    return list.where((v) => v.online).length;
  }

  /// Đếm số xe có cảnh báo cục bộ
  Future<int> countAlertVehicles() async {
    final list = await _fetchAllVehicles();
    return list.where((v) => v.isCritical).length;
  }

  // ==================== NEW REST ENDPOINTS ====================

  /// Kiểm tra trạng thái máy chủ Local Server
  Future<Map<String, dynamic>> checkServerHealth() async {
    final url = Uri.parse('${AppConfig.baseUrl}/health');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('FirestoreService: checkServerHealth error: $e');
    }
    return {'status': 'offline', 'service': 'local-iot-backend', 'database': 'unknown'};
  }

  /// Lấy danh sách các cảnh báo an ninh từ SQLite
  Future<List<Map<String, dynamic>>> fetchAlerts({int limit = 50, bool? resolved}) async {
    String urlStr = '${AppConfig.baseUrl}/api/alerts?limit=$limit';
    if (resolved != null) {
      urlStr += '&resolved=$resolved';
    }
    final url = Uri.parse(urlStr);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['alerts'] is List) {
          return List<Map<String, dynamic>>.from(data['alerts']);
        }
      }
    } catch (e) {
      print('FirestoreService: fetchAlerts error: $e');
    }
    return [];
  }

  /// Đánh dấu đã xử lý cảnh báo (Resolve Alert)
  Future<bool> resolveAlert(int alertId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/alerts/$alertId/resolve');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('FirestoreService: resolveAlert error: $e');
    }
    return false;
  }

  /// Lấy nhật ký hoạt động hệ thống từ SQLite
  Future<List<Map<String, dynamic>>> fetchSystemLogs({int limit = 50}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/system_logs?limit=$limit');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['logs'] is List) {
          return List<Map<String, dynamic>>.from(data['logs']);
        }
      }
    } catch (e) {
      print('FirestoreService: fetchSystemLogs error: $e');
    }
    return [];
  }
}
