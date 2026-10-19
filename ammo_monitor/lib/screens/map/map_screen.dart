import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/transport_data.dart';
import '../../models/mission_model.dart';
import '../../services/firestore_service.dart';
import '../../core/constants/app_config.dart';
import '../transport/transport_detail_screen.dart';

class PlaceNode {
  final int id;
  final String place;
  final double latitude;
  final double longitude;

  const PlaceNode({
    required this.id,
    required this.place,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceNode.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return PlaceNode(
      id: int.tryParse(json['id'].toString()) ?? 0,
      place: json['place']?.toString() ?? 'Unknown place',
      latitude: toDouble(json['lat'] ?? json['latitude']),
      longitude: toDouble(json['lng'] ?? json['lon'] ?? json['longitude']),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}
class _MapScreenState extends State<MapScreen> {
  static String get _baseUrl => AppConfig.baseUrl;

  final MapController _mapController = MapController();

  List<PlaceNode> _places = [];
  List<LatLng> _routePoints = [];

  String? _trackingVehicleId;

  PlaceNode? _startPlace;
  PlaceNode? _goalPlace;

  bool _isLoadingPlaces = false;
  bool _isFindingRoute = false;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Stream<List<TransportData>> _getVehiclesStream() {
    return FirestoreService().streamAllVehicles();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoadingPlaces = true);

    try {
      final url = Uri.parse('$_baseUrl/places');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded['success'] == true) {
        final List rawPlaces = decoded['places'] ?? [];

        setState(() {
          _places = rawPlaces
              .map(
                (item) => PlaceNode.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        });
      } else {
        _showSnackBar(
          decoded['error']?.toString() ?? 'Không tải được danh sách địa điểm.',
          Colors.red,
        );
      }
    } catch (_) {
      _showSnackBar(
        'Không kết nối được server để tải địa điểm. Kiểm tra IP/Wi-Fi nha.',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingPlaces = false);
      }
    }
  }

  Future<void> _selectPlace({required bool isStart}) async {
    if (_isLoadingPlaces) {
      _showSnackBar('Đang tải danh sách địa điểm...', Colors.orange);
      return;
    }

    if (_places.isEmpty) {
      await _loadPlaces();
      if (_places.isEmpty) return;
    }

    final selected = await showModalBottomSheet<PlaceNode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _PlaceSearchSheet(
          title: isStart ? 'Chọn điểm bắt đầu' : 'Chọn điểm đến',
          places: _places,
          selectedPlace: isStart ? _startPlace : _goalPlace,
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (isStart) {
        _startPlace = selected;
      } else {
        _goalPlace = selected;
      }
    });

    _mapController.move(LatLng(selected.latitude, selected.longitude), 15);
  }

  Future<void> _findOptimalRoute() async {
    if (_startPlace == null || _goalPlace == null) {
      _showSnackBar('Vui lòng chọn điểm bắt đầu và điểm đến.', Colors.orange);
      return;
    }

    if (_startPlace!.id == _goalPlace!.id) {
      _showSnackBar('Điểm bắt đầu và điểm đến đang trùng nhau.', Colors.orange);
      return;
    }

    setState(() {
      _isFindingRoute = true;
      _routePoints = [];
      _trackingVehicleId = null;
    });

    try {
      final url = Uri.parse('$_baseUrl/get_route');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'start': _startPlace!.id,
              'goal': _goalPlace!.id,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded['success'] == true) {
        final List pathData = decoded['path'] ?? [];

        final points = pathData.map((node) {
          final lat = (node['lat'] as num).toDouble();
          final lng = (node['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();

        setState(() => _routePoints = points);

        if (_routePoints.isNotEmpty) {
          _fitRouteToMap();
          _showSnackBar('Đã tìm thấy lộ trình phù hợp.', Colors.green);
        }
      } else {
        _showSnackBar(
          decoded['error']?.toString() ?? 'Không tìm thấy đường.',
          Colors.red,
        );
      }
    } catch (_) {
      _showSnackBar(
        'Lỗi kết nối server. Kiểm tra Flask server, IP hoặc Wi-Fi.',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isFindingRoute = false);
      }
    }
  }

  void _fitRouteToMap() {
    if (_routePoints.isEmpty) return;

    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (final point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    _mapController.move(center, 13.8);
  }

  double _distanceBetween(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;

    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  int _nearestRouteIndex(LatLng vehiclePoint) {
    if (_routePoints.isEmpty) return 0;

    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var i = 0; i < _routePoints.length; i++) {
      final distance = _distanceBetween(vehiclePoint, _routePoints[i]);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  List<LatLng> _completedRoutePoints(LatLng vehiclePoint) {
    if (_routePoints.length < 2) return [];

    final nearestIndex = _nearestRouteIndex(vehiclePoint);

    if (nearestIndex <= 0) {
      return [_routePoints.first, vehiclePoint];
    }

    return [..._routePoints.take(nearestIndex + 1), vehiclePoint];
  }

  List<LatLng> _remainingRoutePoints(LatLng vehiclePoint) {
    if (_routePoints.length < 2) return _routePoints;

    final nearestIndex = _nearestRouteIndex(vehiclePoint);

    if (nearestIndex >= _routePoints.length - 1) {
      return [vehiclePoint];
    }

    return [vehiclePoint, ..._routePoints.skip(nearestIndex + 1)];
  }

  Future<void> _assignRoute() async {
    if (_routePoints.isEmpty) {
      _showSnackBar('Chưa có lộ trình để giao cho xe.', Colors.orange);
      return;
    }

    List<TransportData> vehiclesList = [];
    try {
      vehiclesList = await FirestoreService().streamAllVehicles().first;
    } catch (e) {
      _showSnackBar('Lỗi tải danh sách phương tiện: $e', Colors.red);
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chọn xe để giao lộ trình',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2533),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: vehiclesList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final vehicle = vehiclesList[index];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: vehicle.isCritical
                            ? const Color(0xFFFFEEEE)
                            : const Color(0xFFEAF3FF),
                        child: Icon(
                          Icons.local_shipping_outlined,
                          color: vehicle.isCritical
                              ? const Color(0xFFE53935)
                              : const Color(0xFF1C70D1),
                        ),
                      ),
                      title: Text(
                        vehicle.transportId,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        vehicle.isOnline ? 'Đang trực tuyến' : 'Ngoại tuyến',
                      ),
                      onTap: () async {
                        final formattedPoints = _routePoints
                            .map(
                              (point) => {
                                'lat': point.latitude,
                                'lng': point.longitude,
                              },
                            )
                            .toList();

                        final mission = MissionModel(
                          missionId: '',
                          vehicleId: vehicle.vehicleId,
                          driverUid: 'driver_uid', // generic driver for offline mode
                          cargoDescription: 'Vận chuyển đạn dược',
                          origin: _startPlace?.place ?? 'Điểm bắt đầu',
                          destination: _goalPlace?.place ?? 'Điểm đến',
                          status: MissionStatus.pending,
                          createdAt: Timestamp.now(),
                          routePoints: formattedPoints,
                        );

                        try {
                          await FirestoreService().createMission(mission);

                          if (!mounted) return;

                          setState(() {
                            _trackingVehicleId = vehicle.vehicleId;
                          });

                          Navigator.pop(context);

                          _showSnackBar(
                            'Đã giao lộ trình cho ${vehicle.transportId}.',
                            Colors.green,
                          );
                        } catch (e) {
                          _showSnackBar('Lỗi giao lộ trình: $e', Colors.red);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _swapStartGoal() {
    setState(() {
      final temp = _startPlace;
      _startPlace = _goalPlace;
      _goalPlace = temp;
      _routePoints = [];
      _trackingVehicleId = null;
    });
  }

  void _clearRoute() {
    setState(() {
      _startPlace = null;
      _goalPlace = null;
      _routePoints = [];
      _trackingVehicleId = null;
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRoutePolylineLayer() {
    if (_routePoints.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<TransportData>>(
      stream: _getVehiclesStream(),
      builder: (context, snapshot) {
        final vehicles = snapshot.data ?? [];

        TransportData? trackingVehicle;

        for (final vehicle in vehicles) {
          if (vehicle.vehicleId == _trackingVehicleId) {
            trackingVehicle = vehicle;
            break;
          }
        }

        if (trackingVehicle == null) {
          return PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: const Color(0xFF1C70D1).withOpacity(0.85),
              ),
            ],
          );
        }

        final vehiclePoint = LatLng(
          trackingVehicle.latitude,
          trackingVehicle.longitude,
        );

        final completedPoints = _completedRoutePoints(vehiclePoint);
        final remainingPoints = _remainingRoutePoints(vehiclePoint);

        return PolylineLayer(
          polylines: [
            if (completedPoints.length >= 2)
              Polyline(
                points: completedPoints,
                strokeWidth: 5,
                color: const Color(0xFF8A94A6).withOpacity(0.35),
              ),
            if (remainingPoints.length >= 2)
              Polyline(
                points: remainingPoints,
                strokeWidth: 6,
                color: const Color(0xFF1C70D1).withOpacity(0.9),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleMarkerLayer() {
    return StreamBuilder<List<TransportData>>(
      stream: _getVehiclesStream(),
      builder: (context, snapshot) {
        final vehicles = snapshot.data ?? [];

        return MarkerLayer(
          markers: vehicles.map((vehicle) {
            final isTracking = vehicle.vehicleId == _trackingVehicleId;

            return Marker(
              point: LatLng(vehicle.latitude, vehicle.longitude),
              width: isTracking ? 66 : 54,
              height: isTracking ? 66 : 54,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _trackingVehicleId = vehicle.vehicleId;
                  });

                  _mapController.move(
                    LatLng(vehicle.latitude, vehicle.longitude),
                    15.5,
                  );
                  
                  // Hiển thị Bottom Sheet thông tin nhanh
                  _showVehicleSummaryBottomSheet(context, vehicle);
                },
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransportDetailScreen(data: vehicle),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isTracking)
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: vehicle.statusColor.withOpacity(0.16),
                        ),
                      ),
                    Icon(
                      Icons.local_shipping_rounded,
                      color: vehicle.statusColor,
                      size: isTracking ? 44 : 38,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _zoomFitAllVehicles(List<TransportData> vehicles) {
    if (vehicles.isEmpty) return;
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;
    
    for (final v in vehicles) {
      if (v.latitude == 0 && v.longitude == 0) continue;
      if (v.latitude < minLat) minLat = v.latitude;
      if (v.latitude > maxLat) maxLat = v.latitude;
      if (v.longitude < minLon) minLon = v.longitude;
      if (v.longitude > maxLon) maxLon = v.longitude;
    }
    
    if (minLat == double.infinity) return;
    
    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    
    _mapController.move(LatLng(centerLat, centerLon), 13.0);
  }

  void _showVehicleSummaryBottomSheet(BuildContext context, TransportData vehicle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: vehicle.statusColor, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    vehicle.vehicleId,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: vehicle.statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      vehicle.statusText.toUpperCase(),
                      style: TextStyle(color: vehicle.statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _bottomSheetMetric(Icons.battery_charging_full_rounded, "Pin", "${vehicle.battery.toStringAsFixed(0)}%"),
                  _bottomSheetMetric(Icons.thermostat_rounded, "Nhiệt độ", "${vehicle.temperature.toStringAsFixed(1)}°C"),
                  _bottomSheetMetric(Icons.water_drop_rounded, "Độ ẩm", "${vehicle.humidity.toStringAsFixed(0)}%"),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _bottomSheetMetric(Icons.signal_cellular_alt_rounded, "RSSI", "${vehicle.gatewayRssi} dBm"),
                  _bottomSheetMetric(Icons.radar_rounded, "SNR", "${vehicle.gatewaySnr} dB"),
                  _bottomSheetMetric(Icons.lock_rounded, "Nắp hộp", vehicle.tamper == 1 ? "MỞ" : "AN TOÀN"),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C70D1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransportDetailScreen(data: vehicle),
                      ),
                    );
                  },
                  child: const Text("XEM CHI TIẾT VẬN CHUYỂN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomSheetMetric(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _RouteSearchHeader(
              startPlace: _startPlace,
              goalPlace: _goalPlace,
              isLoadingPlaces: _isLoadingPlaces,
              isFindingRoute: _isFindingRoute,
              onSelectStart: () => _selectPlace(isStart: true),
              onSelectGoal: () => _selectPlace(isStart: false),
              onSearchRoute: _findOptimalRoute,
              onSwap: _swapStartGoal,
              onClear: _clearRoute,
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: LatLng(10.801, 106.711),
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'vn.edu.hcmut.ammomonitor',
                      ),

                      if (_routePoints.isNotEmpty) _buildRoutePolylineLayer(),

                      MarkerLayer(
                        markers: [
                          if (_startPlace != null)
                            Marker(
                              point: LatLng(
                                _startPlace!.latitude,
                                _startPlace!.longitude,
                              ),
                              width: 52,
                              height: 52,
                              child: const _RouteMarker(
                                icon: Icons.trip_origin_rounded,
                                color: Color(0xFF20A464),
                              ),
                            ),
                          if (_goalPlace != null)
                            Marker(
                              point: LatLng(
                                _goalPlace!.latitude,
                                _goalPlace!.longitude,
                              ),
                              width: 52,
                              height: 52,
                              child: const _RouteMarker(
                                icon: Icons.location_on_rounded,
                                color: Color(0xFFE53935),
                              ),
                            ),
                        ],
                      ),

                      _buildVehicleMarkerLayer(),
                    ],
                  ),

                  Positioned(
                    bottom: 160,
                    right: 16,
                    child: StreamBuilder<List<TransportData>>(
                      stream: _getVehiclesStream(),
                      builder: (context, snapshot) {
                        final list = snapshot.data ?? [];
                        return FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1C70D1),
                          onPressed: () => _zoomFitAllVehicles(list),
                          tooltip: "Xem toàn bộ xe",
                          child: const Icon(Icons.zoom_out_map_rounded),
                        );
                      }
                    ),
                  ),

                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: _VehicleCarousel(
                      vehiclesStream: _getVehiclesStream(),
                      mapController: _mapController,
                      trackingVehicleId: _trackingVehicleId,
                      onVehicleSelected: (vehicle) {
                        setState(() {
                          _trackingVehicleId = vehicle.vehicleId;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _routePoints.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _assignRoute,
              backgroundColor: const Color(0xFF20A464),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.send_rounded),
              label: const Text(
                'Giao lộ trình',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }
}

class _RouteSearchHeader extends StatelessWidget {
  final PlaceNode? startPlace;
  final PlaceNode? goalPlace;
  final bool isLoadingPlaces;
  final bool isFindingRoute;
  final VoidCallback onSelectStart;
  final VoidCallback onSelectGoal;
  final VoidCallback onSearchRoute;
  final VoidCallback onSwap;
  final VoidCallback onClear;

  const _RouteSearchHeader({
    required this.startPlace,
    required this.goalPlace,
    required this.isLoadingPlaces,
    required this.isFindingRoute,
    required this.onSelectStart,
    required this.onSelectGoal,
    required this.onSearchRoute,
    required this.onSwap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Maps',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2533),
                  ),
                ),
              ),
              if (startPlace != null || goalPlace != null)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Clear',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF8A94A6),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _PlaceInputBox(
                      label: 'Start location',
                      value: startPlace?.place,
                      icon: Icons.trip_origin_rounded,
                      iconColor: const Color(0xFF20A464),
                      onTap: onSelectStart,
                    ),
                    const SizedBox(height: 10),
                    _PlaceInputBox(
                      label: 'Destination',
                      value: goalPlace?.place,
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFE53935),
                      onTap: onSelectGoal,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Column(
                children: [
                  IconButton(
                    onPressed: onSwap,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEAF3FF),
                      foregroundColor: const Color(0xFF1C70D1),
                    ),
                    icon: const Icon(Icons.swap_vert_rounded),
                  ),
                  const SizedBox(height: 10),
                  IconButton.filled(
                    onPressed: isFindingRoute || isLoadingPlaces
                        ? null
                        : onSearchRoute,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1C70D1),
                      disabledBackgroundColor: const Color(0xFF9CC8F6),
                    ),
                    icon: isFindingRoute
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.3,
                            ),
                          )
                        : const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceInputBox extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _PlaceInputBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;

    return Material(
      color: const Color(0xFFF6F8FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7ECF4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasValue ? value! : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasValue
                        ? const Color(0xFF1D2533)
                        : const Color(0xFF8A94A6),
                    fontSize: 14,
                    fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF8A94A6),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchSheet extends StatefulWidget {
  final String title;
  final List<PlaceNode> places;
  final PlaceNode? selectedPlace;

  const _PlaceSearchSheet({
    required this.title,
    required this.places,
    required this.selectedPlace,
  });

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<PlaceNode> get _filteredPlaces {
    final keyword = _normalizeText(_searchController.text.trim());

    if (keyword.isEmpty) {
      return widget.places.take(80).toList();
    }

    return widget.places
        .where((place) {
          final placeName = _normalizeText(place.place);
          final id = place.id.toString();

          return placeName.contains(keyword) || id.contains(keyword);
        })
        .take(80)
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeText(String input) {
    var text = input.toLowerCase();

    const vietnameseMap = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    vietnameseMap.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlaces = _filteredPlaces;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
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

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2533),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Nhập tên địa điểm...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF1C70D1),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF6F8FC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE7ECF4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF1C70D1),
                      width: 1.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: filteredPlaces.isEmpty
                    ? const Center(
                        child: Text(
                          'Không tìm thấy địa điểm phù hợp.',
                          style: TextStyle(
                            color: Color(0xFF8A94A6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filteredPlaces.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];
                          final isSelected =
                              widget.selectedPlace?.id == place.id;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? const Color(0xFF1C70D1)
                                  : const Color(0xFFEAF3FF),
                              child: Icon(
                                Icons.place_outlined,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1C70D1),
                              ),
                            ),
                            title: Text(
                              place.place,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D2533),
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${place.id} · ${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF1C70D1),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(context, place),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RouteMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: color,
      size: 46,
      shadows: [Shadow(color: Colors.black.withOpacity(0.22), blurRadius: 8)],
    );
  }
}

class _VehicleCarousel extends StatelessWidget {
  final Stream<List<TransportData>> vehiclesStream;
  final MapController mapController;
  final String? trackingVehicleId;
  final ValueChanged<TransportData> onVehicleSelected;

  const _VehicleCarousel({
    required this.vehiclesStream,
    required this.mapController,
    required this.trackingVehicleId,
    required this.onVehicleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: StreamBuilder<List<TransportData>>(
        stream: vehiclesStream,
        builder: (context, snapshot) {
          final vehicles = snapshot.data ?? [];

          if (vehicles.isEmpty) {
            return const SizedBox.shrink();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              final isTracking = vehicle.vehicleId == trackingVehicleId;

              return GestureDetector(
                onTap: () {
                  onVehicleSelected(vehicle);

                  mapController.move(
                    LatLng(vehicle.latitude, vehicle.longitude),
                    15.5,
                  );
                },
                child: Container(
                  width: 226,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isTracking
                          ? const Color(0xFF1C70D1)
                          : vehicle.isCritical
                          ? const Color(0xFFFFD9D9)
                          : const Color(0xFFE7ECF4),
                      width: isTracking || vehicle.isCritical ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isTracking
                                  ? const Color(0xFFEAF3FF)
                                  : vehicle.isCritical
                                  ? const Color(0xFFFFEEEE)
                                  : const Color(0xFFEAF3FF),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.local_shipping_outlined,
                              color: vehicle.isCritical
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF1C70D1),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              vehicle.transportId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF1D2533),
                              ),
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Color(0xFF1C70D1),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TransportDetailScreen(data: vehicle),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (isTracking)
                        const Text(
                          'Đang theo dõi tuyến đường',
                          style: TextStyle(
                            color: Color(0xFF1C70D1),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        )
                      else if (vehicle.isCritical)
                        const Text(
                          'Cảnh báo lệch tuyến',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        )
                      else
                        const Text(
                          'Đang theo dõi vị trí',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),

                      const Spacer(),

                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: vehicle.isOnline
                                ? const Color(0xFF20A464)
                                : const Color(0xFF8A94A6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            vehicle.isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
                            style: TextStyle(
                              color: vehicle.isOnline
                                  ? const Color(0xFF20A464)
                                  : const Color(0xFF8A94A6),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isTracking ? 'Đang chọn' : 'Xem vị trí',
                            style: TextStyle(
                              color: isTracking
                                  ? const Color(0xFF1C70D1)
                                  : const Color(0xFF1C70D1),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
