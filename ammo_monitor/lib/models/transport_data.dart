import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransportData {
  final String transportId;
  final String vehicleId;
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
  final String rfAnomaly; 
  final String knnPrediction;
  final String mlPrediction;
  final String rfAnomalyState;
  final double mlScore;      
  final bool online;
  final double battery;
  final Timestamp lastUpdated;

  TransportData({
    required this.transportId,
    required this.vehicleId,
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
    required this.rfAnomaly,
    required this.knnPrediction,
    required this.mlPrediction,
    required this.rfAnomalyState,
    required this.mlScore,
    required this.online,
    required this.battery,
    required this.lastUpdated,
  });

  // Ngưỡng cảnh báo
  static const double tempThreshold = 40.0;
  static const double humidityThreshold = 70.0;
  static const double accelThreshold = 2.0;

  bool get isTempDanger => temperature > tempThreshold;
  bool get isHumidityDanger => humidity > humidityThreshold;
  bool get isVibrationDanger => accelMagnitude > accelThreshold;

  String get formattedGPS {
    if (latitude == 0 && longitude == 0) return "Đang cập nhật...";
    String latSide = latitude >= 0 ? 'N' : 'S';
    String lonSide = longitude >= 0 ? 'E' : 'W';
    return "[${latitude.abs().toStringAsFixed(4)}° $latSide, ${longitude.abs().toStringAsFixed(4)}° $lonSide]";
  }

  bool get isLowBattery => battery < 20.0;
  bool get isCritical => mlPrediction == "OUT_OF_ROUTE" || anomalyFlag == 1 || tamper == 1 || isLowBattery;
  bool get isOnline => statusText == 'Online' || statusText == 'Warning' || statusText == 'Critical';

  String get statusText {
    final nowUtc = DateTime.now().toUtc();
    final lastUpdatedUtc = lastUpdated.toDate().toUtc();
    final diffSec = nowUtc.difference(lastUpdatedUtc).inSeconds.abs();
    if (diffSec >= 120 || !online) return 'Offline';
    if (isCritical) return 'Critical';
    if (diffSec >= 30) return 'Warning';
    return 'Online';
  }

  Color get statusColor {
    switch (statusText) {
      case 'Critical':
        return const Color(0xFFE53935);
      case 'Warning':
        return Colors.orange;
      case 'Offline':
        return const Color(0xFF8A94A6);
      default:
        return const Color(0xFF20A464);
    }
  }

  String get mlPredictionDisplay {
    switch (mlPrediction) {
      case "OUT_OF_ROUTE":
        return "Lệch tuyến đường";
      case "NORMAL":
        return "Đúng tuyến";
      default:
        return mlPrediction;
    }
  }

  factory TransportData.fromFirestore(DocumentSnapshot doc) {
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

    return TransportData(
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
      rfAnomaly: data['rf_anomaly_state'] ?? 'NORMAL',
      knnPrediction: data['knn_prediction'] ?? 'NORMAL',
      mlPrediction: data['ml_prediction'] ?? 'NORMAL',
      rfAnomalyState: data['rf_anomaly_state'] ?? 'NORMAL',
      mlScore: toDouble(data['ml_score']),
      online: data['online'] == true,
      battery: toDouble(data['battery_last'] ?? data['battery'] ?? 100.0),
      lastUpdated: data['last_updated'] is Timestamp
          ? data['last_updated']
          : Timestamp.now(),
    );
  }

  factory TransportData.fromJson(Map<String, dynamic> data) {
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

    return TransportData(
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
      rfAnomaly: data['rf_anomaly_state'] ?? 'NORMAL',
      knnPrediction: data['knn_prediction'] ?? 'NORMAL',
      mlPrediction: data['ml_prediction'] ?? 'NORMAL',
      rfAnomalyState: data['rf_anomaly_state'] ?? 'NORMAL',
      mlScore: toDouble(data['ml_score']),
      online: data['online'] == true,
      battery: toDouble(data['battery_last'] ?? data['battery'] ?? 100.0),
      lastUpdated: lastUpdatedTs,
    );
  }
}
