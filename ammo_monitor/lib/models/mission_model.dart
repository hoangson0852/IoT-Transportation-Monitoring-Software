import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái nhiệm vụ vận chuyển
enum MissionStatus { pending, inProgress, completed, cancelled }

/// Model cho một lệnh/nhiệm vụ vận chuyển
class MissionModel {
  final String missionId;
  final String vehicleId;
  final String driverUid;
  final String cargoDescription;
  final String origin;
  final String destination;
  final MissionStatus status;
  final Timestamp createdAt;
  final Timestamp? startedAt;
  final Timestamp? completedAt;
  final String? notes;
  final List<Map<String, double>> routePoints; // [{lat, lng}]

  MissionModel({
    required this.missionId,
    required this.vehicleId,
    required this.driverUid,
    required this.cargoDescription,
    required this.origin,
    required this.destination,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.routePoints = const [],
  });

  String get statusLabel {
    switch (status) {
      case MissionStatus.pending:
        return 'Chờ xác nhận';
      case MissionStatus.inProgress:
        return 'Đang vận chuyển';
      case MissionStatus.completed:
        return 'Hoàn thành';
      case MissionStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  factory MissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MissionModel(
      missionId: doc.id,
      vehicleId: data['vehicle_id'] ?? '',
      driverUid: data['driver_uid'] ?? '',
      cargoDescription: data['cargo_description'] ?? 'Đạn dược',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: data['created_at'] ?? Timestamp.now(),
      startedAt: data['started_at'],
      completedAt: data['completed_at'],
      notes: data['notes'],
      routePoints: _parseRoutePoints(data['route_points']),
    );
  }

  factory MissionModel.fromJson(Map<String, dynamic> data) {
    Timestamp parseTimestamp(dynamic val) {
      if (val is String) {
        return Timestamp.fromDate(DateTime.parse(val));
      } else if (val is Timestamp) {
        return val;
      }
      return Timestamp.now();
    }
    Timestamp? parseNullableTimestamp(dynamic val) {
      if (val == null) return null;
      if (val is String) {
        return Timestamp.fromDate(DateTime.parse(val));
      } else if (val is Timestamp) {
        return val;
      }
      return null;
    }

    return MissionModel(
      missionId: data['mission_id'] ?? '',
      vehicleId: data['vehicle_id'] ?? '',
      driverUid: data['driver_uid'] ?? '',
      cargoDescription: data['cargo_description'] ?? 'Đạn dược',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: parseTimestamp(data['created_at']),
      startedAt: parseNullableTimestamp(data['started_at']),
      completedAt: parseNullableTimestamp(data['completed_at']),
      notes: data['notes'],
      routePoints: _parseRoutePoints(data['route_points']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'vehicle_id': vehicleId,
    'driver_uid': driverUid,
    'cargo_description': cargoDescription,
    'origin': origin,
    'destination': destination,
    'status': status.name,
    'created_at': createdAt,
    'started_at': startedAt,
    'completed_at': completedAt,
    'notes': notes,
    'route_points': routePoints,
  };

  static MissionStatus _parseStatus(dynamic val) {
    switch (val?.toString()) {
      case 'inProgress':
        return MissionStatus.inProgress;
      case 'completed':
        return MissionStatus.completed;
      case 'cancelled':
        return MissionStatus.cancelled;
      default:
        return MissionStatus.pending;
    }
  }

  static List<Map<String, double>> _parseRoutePoints(dynamic val) {
    if (val is! List) return [];
    return val.map((p) {
      if (p is Map) {
        return {
          'lat': (p['lat'] as num?)?.toDouble() ?? 0.0,
          'lng': (p['lng'] as num?)?.toDouble() ?? 0.0,
        };
      }
      return {'lat': 0.0, 'lng': 0.0};
    }).toList();
  }
}
