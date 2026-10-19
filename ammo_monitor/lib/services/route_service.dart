import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants/app_config.dart';

class RouteService {
  double _distanceBetween(LatLng a, LatLng b) {
    const earthRadius = 6371.0; // In kilometers

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

  Future<Map<String, dynamic>> getRoute(int startId, int goalId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/get_route');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start': startId,
          'goal': goalId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['path'] is List) {
          final list = data['path'] as List;
          final points = list.map((node) {
            return LatLng(
              (node['lat'] as num).toDouble(),
              (node['lng'] as num).toDouble(),
            );
          }).toList();

          double totalDistance = 0.0;
          for (int i = 0; i < points.length - 1; i++) {
            totalDistance += _distanceBetween(points[i], points[i + 1]);
          }

          return {
            'success': true,
            'distance': totalDistance,
            'points': points,
          };
        } else {
          return {'success': false, 'error': data['error'] ?? 'Không tìm thấy đường.'};
        }
      }
      return {'success': false, 'error': 'Lỗi kết nối Local Server (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
