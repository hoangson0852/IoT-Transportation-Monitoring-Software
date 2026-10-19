import 'package:flutter/material.dart';

import '../../models/transport_data.dart';
import '../../services/firestore_service.dart';
import '../home/widgets/alert_card.dart';

class TodayAlertScreen extends StatelessWidget {
  const TodayAlertScreen({super.key});

  Stream<List<TransportData>> _criticalVehiclesStream() {
    return FirestoreService().streamAllVehicles().map(
          (list) => list.where((vehicle) => vehicle.isCritical).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Today's Alert",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D2533),
          ),
        ),
      ),
      body: StreamBuilder<List<TransportData>>(
        stream: _criticalVehiclesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.verified_outlined,
                        color: Color(0xFF1C70D1),
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'All vehicles are normal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D2533),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Critical alerts will be listed here when detected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return AlertCard(data: alerts[index]);
            },
          );
        },
      ),
    );
  }
}