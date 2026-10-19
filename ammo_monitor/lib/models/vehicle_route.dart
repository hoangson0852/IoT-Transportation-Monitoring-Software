import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class VehicleRoute {
  final String vehicleId;
  final List<LatLng> points; // Danh sách tọa độ để vẽ đường

  VehicleRoute({required this.vehicleId, required this.points});

  factory VehicleRoute.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Giả sử trong Firestore, 'route' là một List các GeoPoint
    List<dynamic> routeData = data['route'] ?? [];
    
    List<LatLng> points = routeData.map((point) {
      if (point is GeoPoint) {
        return LatLng(point.latitude, point.longitude);
      }
      return const LatLng(0, 0);
    }).toList();

    return VehicleRoute(
      vehicleId: doc.id,
      points: points,
    );
  }
}
