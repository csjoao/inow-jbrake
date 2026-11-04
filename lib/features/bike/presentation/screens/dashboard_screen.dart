import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/bike_state.dart';
import '../providers/bike_providers.dart';

/// Painel da bike conectada (velocidade, bateria, modo, trava).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(bikeControllerProvider);
    final c = ref.read(bikeControllerProvider.notifier);

    ref.listen(bikeControllerProvider.select((s) => s.error), (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'inow',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            onSelected: (v) async {
              switch (v) {
                case 'settings':
                  await context.push(AppRoutes.settings);
                case 'info':
                  await context.push(AppRoutes.info);
                case 'console':
                  await context.push(AppRoutes.console);
                case 'disconnect':
                  await c.disconnect();
                  if (context.mounted) context.pop();
                case 'forget':
                  await c.forgetBike();
                  if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Ajustes')),
              PopupMenuItem(value: 'info', child: Text('Dados do veículo')),
              PopupMenuItem(value: 'console', child: Text('Console')),
              PopupMenuItem(value: 'disconnect', child: Text('Desconectar')),
              PopupMenuItem(value: 'forget', child: Text('Esquecer bike')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SpeedHeader(speed: s.speed),
          const SizedBox(height: 16),
          _StatusCard(state: s),
          const SizedBox(height: 16),
          _StatsCard(state: s),
          const SizedBox(height: 16),
          _ModeRow(
            mode: s.mode,
            enabled: s.isConnected,
            onMinus: () => c.setMode((s.mode ?? 1) - 1),
            onPlus: () => c.setMode((s.mode ?? 0) + 1),
          ),
          const SizedBox(height: 16),
          _ToggleCard(
            icon: s.locked == true ? Icons.lock_outline : Icons.lock_open,
            label: s.locked == true ? 'Travada' : 'Destravada',
            value: s.locked ?? false,
            onChanged: s.isConnected ? c.setLocked : null,
          ),
          const SizedBox(height: 16),
          _ToggleCard(
            icon: s.headlight == true
                ? Icons.flashlight_on
                : Icons.flashlight_off_outlined,
            label: s.headlight == true ? 'Farol ligado' : 'Farol desligado',
            value: s.headlight ?? false,
            onChanged: s.isConnected ? c.setHeadlight : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _QuickAction(
                icon: Icons.info_outline,
                label: 'Dados',
                onTap: () => context.push(AppRoutes.info),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.tune,
                label: 'Ajustes',
                onTap: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.nfc,
                label: 'NFC',
                onTap: () => context.push(AppRoutes.nfc),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedHeader extends StatelessWidget {
  const _SpeedHeader({required this.speed});

  final double speed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      speed.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'km/h',
                      style: TextStyle(fontSize: 22, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'SPEED',
                  style: TextStyle(fontSize: 22, color: AppColors.yellow),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Icon(
              Icons.electric_bike,
              size: 140,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final BikeState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.phase) {
      BikePhase.connected => 'Connected',
      BikePhase.connecting => 'Conectando...',
      BikePhase.authenticating => 'Autenticando...',
      BikePhase.disconnected => 'Desconectado',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.name ?? '-',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (state.model != null)
                    Text(
                      state.model!,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFF9DB),
                  child: Icon(
                    Icons.bluetooth,
                    color: state.isConnected
                        ? AppColors.yellow
                        : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.state});

  final BikeState state;

  @override
  Widget build(BuildContext context) {
    String km(double? v) => v == null ? '-' : v.toStringAsFixed(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _Stat(value: km(state.trip), unit: 'km', label: 'Viagem'),
              const VerticalDivider(),
              _Stat(
                value: state.battery?.toString() ?? '-',
                unit: '%',
                label: 'Bateria',
              ),
              const VerticalDivider(),
              _Stat(value: km(state.odo), unit: 'km', label: 'ODO'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit, required this.label});

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 30)),
              Text(unit, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
  });

  final int? mode;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback onTap) => Expanded(
      flex: 2,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(height: 72, child: Icon(icon, size: 32)),
        ),
      ),
    );

    return Row(
      children: [
        button(Icons.remove, onMinus),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Card(
            child: SizedBox(
              height: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    mode?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text('  MODE', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        button(Icons.add, onPlus),
      ],
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppColors.muted)),
            const Spacer(),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 6),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
