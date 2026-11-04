import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/fleet_bike.dart';
import '../providers/fleet_providers.dart';
import 'status_tag.dart';

/// Cartão de uma bike na tela "Bicicletas".
class FleetBikeCard extends StatelessWidget {
  const FleetBikeCard({
    super.key,
    required this.bike,
    this.activeStep,
    this.blocked = false,
    this.onToggleBlock,
  });

  final FleetBike bike;

  /// Na lista de bloqueio: aparece, mas a operação pula.
  final bool blocked;
  final VoidCallback? onToggleBlock;

  /// Etapa em andamento, quando esta é a bike sendo processada.
  final FleetStep? activeStep;

  static IconData featureIcon(BikeFeature f) => switch (f) {
    BikeFeature.gear => Icons.speed,
    BikeFeature.lock => Icons.lock_outline,
    BikeFeature.headlight => Icons.flashlight_on_outlined,
    BikeFeature.nfc => Icons.nfc,
    BikeFeature.cruise => Icons.av_timer,
  };

  @override
  Widget build(BuildContext context) {
    final active = activeStep != null;
    final tint = StatusTag.styleOf(bike.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: active
              ? const BorderSide(color: AppColors.yellow, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: tint.bg,
                    child: Icon(Icons.electric_bike, color: tint.fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bike.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          bike.model ?? 'Modelo aparece ao conectar',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        Text(
                          bike.id,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (blocked)
                        const BlockedTag()
                      else
                        StatusTag(bike.status),
                      if (bike.rssi != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${bike.rssi} dBm',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (bike.features.isEmpty)
                const Text(
                  'Funcionalidades aparecem ao conectar',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in bike.features)
                    Chip(
                      avatar: Icon(featureIcon(f), size: 16),
                      label: Text(f.label),
                      labelStyle: const TextStyle(fontSize: 12),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      backgroundColor: Colors.white,
                    ),
                ],
              ),
              if (active) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(activeStep!.label),
                  ],
                ),
              ] else if (blocked) ...[
                const SizedBox(height: 10),
                const Text(
                  'A operação pula esta bicicleta.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ] else if (bike.message != null) ...[
                const SizedBox(height: 10),
                Text(
                  bike.message!,
                  style: TextStyle(color: tint.fg, fontSize: 13),
                ),
              ],
              if (onToggleBlock != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: blocked
                          ? AppColors.text
                          : const Color(0xFFC62828),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onToggleBlock,
                    icon: Icon(
                      blocked ? Icons.check_circle_outline : Icons.block,
                      size: 18,
                    ),
                    label: Text(blocked ? 'Desbloquear' : 'Bloquear'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
