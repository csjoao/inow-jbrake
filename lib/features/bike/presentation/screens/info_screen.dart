import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/bike_providers.dart';
import '../widgets/section.dart';

/// "Informações do veículo", "Sistema" e "Pedalada" do app oficial.
///
/// A bike envia esses dados sozinha de tempos em tempos; o que ainda não
/// chegou aparece como "—".
class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(bikeControllerProvider);
    final i = s.info;

    String n(num? v, String unit, {int digits = 1}) =>
        v == null ? '—' : '${v.toStringAsFixed(digits)} $unit';
    String hours(int? sec) => sec == null ? '—' : n(sec / 3600, 'h');
    String version(double? v) => v == null ? '—' : 'v${v.toStringAsFixed(1)}';

    Widget card(List<Widget> rows) => Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(children: rows),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dados do veículo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Bike'),
          card([
            InfoRow('Nome', s.name ?? '—'),
            InfoRow('Modelo', s.model ?? '—'),
            InfoRow('ID Bluetooth', s.deviceId ?? '—'),
            InfoRow('Software', version(i.software)),
            InfoRow('Firmware', version(i.firmware)),
          ]),
          const SectionTitle('Bateria e motor'),
          card([
            InfoRow('Bateria', s.battery == null ? '—' : '${s.battery} %'),
            InfoRow('Tensão', n(i.voltage, 'V')),
            InfoRow('Corrente', n(i.current, 'A')),
            InfoRow('Potência (estimada)', n(i.power, 'W')),
            InfoRow('Ciclos de carga', i.chargeCycles?.toString() ?? '—'),
          ]),
          const SectionTitle('Pedalada atual'),
          card([
            InfoRow('Distância', n(i.rideDistance ?? s.trip, 'km')),
            InfoRow('Tempo', hours(i.rideSeconds)),
            InfoRow('Velocidade média', n(i.rideAverageSpeed, 'km/h')),
            InfoRow('Velocidade máxima', n(i.rideTopSpeed, 'km/h')),
          ]),
          const SectionTitle('Total'),
          card([
            InfoRow('ODO', n(i.totalDistance ?? s.odo, 'km')),
            InfoRow('Tempo total', hours(i.totalSeconds)),
          ]),
          const SizedBox(height: 16),
          Text(
            'Pacotes recebidos: '
            '${s.telemetryFormats.isEmpty ? "nenhum ainda" : s.telemetryFormats.join(", ")}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
