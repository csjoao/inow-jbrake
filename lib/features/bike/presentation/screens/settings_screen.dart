import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/protocol/inow_commands.dart';
import '../providers/bike_providers.dart';
import '../widgets/section.dart';

/// Ajustes do app oficial, agrupados. Ao abrir, consulta os valores atuais.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(bikeControllerProvider.notifier).queryAll([
        for (final s in allChoiceSettings) s.query,
        InowCommands.maxSpeedQuery,
        InowCommands.standbyQuery,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = ref.watch(bikeControllerProvider.select((s) => s.values));

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Condução'),
          for (final s in ridingSettings)
            _ChoiceTile(setting: s, values: values),
          const SectionTitle('Velocidade'),
          for (final s in speedSettings)
            _ChoiceTile(setting: s, values: values),
          _SliderTile(
            title: 'Velocidade máxima',
            unit: 'km/h',
            min: 10,
            max: 60,
            current: _maxSpeed(values['SPLT']),
            command: InowCommands.maxSpeed,
            query: InowCommands.maxSpeedQuery,
          ),
          const SectionTitle('Painel e luzes'),
          for (final s in displaySettings)
            _ChoiceTile(setting: s, values: values),
          _SliderTile(
            title: 'Desligamento automático',
            unit: 'min',
            min: 1,
            max: 30,
            current: int.tryParse(values['STBY'] ?? ''),
            command: InowCommands.standby,
            query: InowCommands.standbyQuery,
          ),
          const SectionTitle('Segurança'),
          NavTile(
            icon: Icons.password,
            title: 'Senhas e Bluetooth',
            subtitle: 'Senha de conexão, trava, marcha e nome da bike',
            onTap: () => context.push(AppRoutes.security),
          ),
          NavTile(
            icon: Icons.nfc,
            title: 'Cartões NFC',
            subtitle: 'Destravar a bike encostando um cartão',
            onTap: () => context.push(AppRoutes.nfc),
          ),
          const SectionTitle('Informações'),
          NavTile(
            icon: Icons.info_outline,
            title: 'Dados do veículo',
            subtitle: 'Bateria, potência, versões e pedalada',
            onTap: () => context.push(AppRoutes.info),
          ),
          NavTile(
            icon: Icons.terminal,
            title: 'Console',
            subtitle: 'Ver e enviar comandos Bluetooth',
            onTap: () => context.push(AppRoutes.console),
          ),
        ],
      ),
    );
  }

  /// `+SPLT=0XX` → XX.
  static int? _maxSpeed(String? v) {
    if (v == null || v.length < 2) return null;
    return int.tryParse(v.substring(v.length - 2));
  }
}

class _ChoiceTile extends ConsumerWidget {
  const _ChoiceTile({required this.setting, required this.values});

  final InowSetting setting;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(bikeControllerProvider.notifier);
    final current = values[setting.key];
    return SettingCard(
      title: setting.title,
      subtitle: '+${setting.key}  •  atual: ${current ?? "?"}',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in setting.options.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: current == e.key,
              selectedColor: AppColors.yellow,
              onSelected: (_) =>
                  c.setAndQuery(setting.set(e.key), setting.query),
            ),
        ],
      ),
    );
  }
}

class _SliderTile extends ConsumerStatefulWidget {
  const _SliderTile({
    required this.title,
    required this.unit,
    required this.min,
    required this.max,
    required this.current,
    required this.command,
    required this.query,
  });

  final String title;
  final String unit;
  final int min;
  final int max;
  final int? current;
  final String Function(int) command;
  final String query;

  @override
  ConsumerState<_SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends ConsumerState<_SliderTile> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value =
        (_dragging ?? widget.current?.toDouble() ?? widget.min.toDouble())
            .clamp(widget.min.toDouble(), widget.max.toDouble());
    return SettingCard(
      title: widget.title,
      subtitle: widget.current == null
          ? 'atual: ?'
          : 'atual: ${widget.current} ${widget.unit}',
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value,
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.max - widget.min,
              activeColor: AppColors.yellow,
              label: '${value.round()} ${widget.unit}',
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) async {
                setState(() => _dragging = null);
                await ref
                    .read(bikeControllerProvider.notifier)
                    .setAndQuery(widget.command(v.round()), widget.query);
              },
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${value.round()} ${widget.unit}',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
