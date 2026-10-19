import 'package:flutter/material.dart';

// ==================== Models ====================
import '../../models/transport_data.dart';
import '../../services/firestore_service.dart';

// ==================== Home widgets ====================
import 'widgets/header.dart';
import 'widgets/overview_card.dart';
import 'widgets/section_header.dart';
import 'widgets/transport_card.dart';
import 'widgets/alert_card.dart';
import 'widgets/home_navbar.dart';

// ==================== Screens ====================
import '../transport/today_transport_screen.dart';
import '../alert/today_alert_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../transport/transport_detail_screen.dart';
import '../dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = const [
      _HomeContent(),
      DashboardScreen(),
      MapScreen(),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: HomeNavBar(
        currentIndex: _currentIndex,
        onChanged: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  Stream<List<TransportData>> _vehiclesStream() {
    return FirestoreService().streamAllVehicles();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<TransportData>>(
        stream: _vehiclesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final vehicles = snapshot.data ?? [];
          final activeVehicles = vehicles.where((v) => v.isOnline).toList();
          final alertVehicles = vehicles.where((v) => v.isCritical).toList();

          final latestVehicles = activeVehicles.isNotEmpty
              ? activeVehicles.take(3).toList()
              : vehicles.take(3).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  const HeaderSection(),
                  const SizedBox(height: 20),

                  OverviewCard(
                    transportingCount: activeVehicles.length,
                    deviceCount: vehicles.length,
                    alertCount: alertVehicles.length,
                  ),

                  const SizedBox(height: 24),

                  SectionHeader(
                    title: "Today's Transport",
                    count: activeVehicles.length,
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TodayTransportScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  if (latestVehicles.isEmpty)
                    const _EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'No active transport',
                      message:
                          'Transport data will appear here when a vehicle is online.',
                    )
                  else
                    ...latestVehicles.map(
                      (vehicle) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TransportCard(
                          data: vehicle,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TransportDetailScreen(data: vehicle),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  SectionHeader(
                    title: "Today's Alert",
                    count: alertVehicles.length,
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TodayAlertScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  if (alertVehicles.isEmpty)
                    const _EmptyState(
                      icon: Icons.verified_outlined,
                      title: 'All vehicles are normal',
                      message: 'No critical route alert has been detected today.',
                    )
                  else
                    ...alertVehicles.take(2).map(
                          (vehicle) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AlertCard(data: vehicle),
                          ),
                        ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1C70D1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2533),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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