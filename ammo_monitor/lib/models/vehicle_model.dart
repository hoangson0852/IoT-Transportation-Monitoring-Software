import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho dữ liệu thời gian thực của xe (vehicles collection)
class VehicleModel {
  final String vehicleId;
  final String transportId;
  final double temperature;
  final double humidity;
  final double latitude;
  final double longitude;
  final int lightLevel;
  final double accelMagnitude;
  final int gatewayRssi;
  final int gatewaySnr;
  final int tamper;
  final int anomalyFlag;
  final String rfAnomalyState;
  final String knnPrediction;
  final String mlPrediction;
  final double mlScore;
  final bool online;
  final Timestamp lastUpdated;

  VehicleModel({
    required this.vehicleId,
    required this.transportId,
    required this.temperature,
    required this.humidity,
    required this.latitude,
    required this.longitude,
    required this.lightLevel,
    required this.accelMagnitude,
    required this.gatewayRssi,
    required this.gatewaySnr,
    required this.tamper,
    required this.anomalyFlag,
    required this.rfAnomalyState,
    required this.knnPrediction,
    required this.mlPrediction,
    required this.mlScore,
    required this.online,
    required this.lastUpdated,
  });

  // ===== Thresholds =====
  static const double tempThreshold = 40.0;
  static const double humidityThreshold = 70.0;
  static const double accelThreshold = 2.0;

  // ===== Computed getters =====
  bool get isTempDanger => temperature > tempThreshold;
  bool get isHumidityDanger => humidity > humidityThreshold;
  bool get isVibrationDanger => accelMagnitude > accelThreshold;
  bool get isTampered => tamper == 1;
  bool get isRouteDeviated => mlPrediction != 'NORMAL';
  bool get isSensorAnomaly => anomalyFlag == 1;
  bool get isOnline => online;
  bool get hasAlert => isRouteDeviated || isSensorAnomaly || isTampered;

  String get statusText {
    if (isRouteDeviated) return 'CRITICAL';
    if (hasAlert) return 'ALERT';
    if (!isOnline) return 'OFFLINE';
    return 'NORMAL';
  }

  String get formattedGPS {
    if (latitude == 0 && longitude == 0) return 'Đang cập nhật...';
    final latSide = latitude >= 0 ? 'N' : 'S';
    final lonSide = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(5)}°$latSide, ${longitude.abs().toStringAsFixed(5)}°$lonSide';
  }

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    double toDouble(dynamic val) => (val is num) ? val.toDouble() : 0.0;

    double lat = 0.0;
    double lon = 0.0;

    if (data['gps'] is GeoPoint) {
      lat = (data['gps'] as GeoPoint).latitude;
      lon = (data['gps'] as GeoPoint).longitude;
    } else if (data['GPS'] is GeoPoint) {
      lat = (data['GPS'] as GeoPoint).latitude;
      lon = (data['GPS'] as GeoPoint).longitude;
    } else if (data['gps_latitude'] != null) {
      lat = toDouble(data['gps_latitude']);
      lon = toDouble(data['gps_longitude']);
    } else if (data['latitude'] != null) {
      lat = toDouble(data['latitude']);
      lon = toDouble(data['longitude']);
    }

    return VehicleModel(
      vehicleId: data['vehicle_id'] ?? doc.id,
      transportId: data['transport_id'] ?? (data['vehicle_id'] ?? doc.id),
      temperature: toDouble(data['temperature']),
      humidity: toDouble(data['humidity']),
      lightLevel: data['light_level'] ?? 0,
      accelMagnitude: toDouble(data['accel_magnitude'] ?? data['a_g']),
      gatewayRssi: data['gateway_rssi'] ?? 0,
      gatewaySnr: data['gateway_snr'] ?? 0,
      latitude: lat,
      longitude: lon,
      tamper: data['tamper'] ?? 0,
      anomalyFlag: data['anomaly_flag'] ?? 0,
      rfAnomalyState: data['rf_anomaly_state'] ?? 'NORMAL',
      knnPrediction: data['knn_prediction'] ?? 'NORMAL',
      mlPrediction: data['ml_prediction'] ?? 'NORMAL',
      mlScore: toDouble(data['ml_score']),
      online: data['online'] == true,
      lastUpdated: data['last_updated'] ?? Timestamp.now(),
    );
  }

  factory VehicleModel.fromJson(Map<String, dynamic> data) {
    double toDouble(dynamic val) => (val is num) ? val.toDouble() : 0.0;
    
    Timestamp lastUpdatedTs;
    final lu = data['last_updated'];
    if (lu is String) {
      lastUpdatedTs = Timestamp.fromDate(DateTime.parse(lu));
    } else if (lu is Timestamp) {
      lastUpdatedTs = lu;
    } else {
      lastUpdatedTs = Timestamp.now();
    }

    return VehicleModel(
      vehicleId: data['vehicle_id'] ?? '',
      transportId: data['transport_id'] ?? (data['vehicle_id'] ?? ''),
      temperature: toDouble(data['temperature']),
      humidity: toDouble(data['humidity']),
      lightLevel: data['light_level'] ?? 0,
      accelMagnitude: toDouble(data['accel_magnitude']),
      gatewayRssi: data['gateway_rssi'] ?? 0,
      gatewaySnr: data['gateway_snr'] ?? 0,
      latitude: toDouble(data['latitude']),
      longitude: toDouble(data['longitude']),
      tamper: data['tamper'] ?? 0,
      anomalyFlag: data['anomaly_flag'] ?? 0,
      rfAnomalyState: data['rf_anomaly_state'] ?? 'NORMAL',
      knnPrediction: data['knn_prediction'] ?? 'NORMAL',
      mlPrediction: data['ml_prediction'] ?? 'NORMAL',
      mlScore: toDouble(data['ml_score']),
      online: data['online'] == true,
      lastUpdated: lastUpdatedTs,
    );
  }
}
