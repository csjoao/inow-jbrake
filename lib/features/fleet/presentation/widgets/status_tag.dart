import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/fleet_bike.dart';

/// Etiqueta "Bloqueada" (bike na lista de bloqueio).
class BlockedTag extends StatelessWidget {
  const BlockedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Bloqueada',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta colorida do estado da bike.
class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});

  final FleetBikeStatus status;

  static ({Color bg, Color fg, IconData icon}) styleOf(FleetBikeStatus s) =>
      switch (s) {
        FleetBikeStatus.connected => (
          bg: const Color(0xFFFFF5CC),
          fg: const Color(0xFF8A6D00),
          icon: Icons.bluetooth_connected,
        ),
        FleetBikeStatus.disconnected => (
          bg: const Color(0xFFEDEDF0),
          fg: AppColors.muted,
          icon: Icons.bluetooth_disabled,
        ),
        FleetBikeStatus.completed => (
          bg: const Color(0xFFE3F5E8),
          fg: const Color(0xFF1E7B3A),
          icon: Icons.check_circle_outline,
        ),
        FleetBikeStatus.failed => (
          bg: const Color(0xFFFDE7E7),
          fg: const Color(0xFFC62828),
          icon: Icons.error_outline,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final st = styleOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: 14, color: st.fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: st.fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
