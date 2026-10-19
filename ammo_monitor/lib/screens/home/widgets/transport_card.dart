import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/transport_data.dart';

class TransportCard extends StatelessWidget {
  final TransportData data;
  final VoidCallback? onTap;

  const TransportCard({
    super.key,
    required this.data,
    this.onTap,
  });

  Color get _statusColor {
    if (data.isCritical) return const Color(0xFFE53935);
    if (!data.isOnline) return const Color(0xFF8A94A6);
    return const Color(0xFF20A464);
  }

  String get _statusText {
    if (data.isCritical) return 'Critical';
    if (!data.isOnline) return 'Offline';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final updatedAt = DateFormat(
      'dd MMM, HH:mm',
    ).format(data.lastUpdated.toDate());

    final progress = data.isCritical
        ? 0.78
        : data.isOnline
            ? 0.46
            : 0.12;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE7ECF4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF1C70D1),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.transportId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D2533),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Vehicle ID: ${data.vehicleId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF8A94A6),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  _Chip(
                    label: data.isOnline ? 'On route' : 'Disconnected',
                    color: const Color(0xFF1C70D1),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: _statusText,
                    color: _statusColor,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: progress,
                  backgroundColor: const Color(0xFFE7ECF4),
                  color: _statusColor,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  _Metric(
                    icon: Icons.thermostat,
                    text: '${data.temperature.toStringAsFixed(1)}°C',
                  ),
                  const SizedBox(width: 12),
                  _Metric(
                    icon: Icons.water_drop_outlined,
                    text: '${data.humidity.toStringAsFixed(0)}%',
                  ),
                  const SizedBox(width: 12),
                  _Metric(
                    icon: data.battery < 20 ? Icons.battery_alert_rounded : Icons.battery_std_rounded,
                    text: '${data.battery.toStringAsFixed(0)}%',
                    iconColor: data.battery < 20 ? const Color(0xFFE53935) : const Color(0xFF20A464),
                  ),
                  const Spacer(),
                  _Metric(
                    icon: Icons.schedule,
                    text: updatedAt,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const _Metric({
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}