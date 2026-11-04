import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../bike/presentation/widgets/section.dart';
import '../../../fleet/presentation/providers/fleet_blocklist_providers.dart';
import '../../domain/entities/app_settings.dart';
import '../providers/app_settings_providers.dart';

/// Configurações da aplicação (salvas no aparelho). Diferente de "Ajustes",
/// que envia comandos para a bike conectada.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final c = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          IconButton(
            tooltip: 'Restaurar padrões',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              await c.resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configurações restauradas.')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Busca'),
          SettingCard(
            title: 'Tempo máximo de busca',
            subtitle:
                'Sem bicicletas, continua procurando até este limite. '
                'Com bicicletas, para 3 s depois da última encontrada.',
            child: _IntSlider(
              value: s.scanSeconds,
              range: AppSettings.scanRange,
              unit: 's',
              onChanged: (v) => c.update(s.copyWith(scanSeconds: v)),
            ),
          ),
          const SectionTitle('Conexão'),
          _PasswordCard(
            // Recria o campo quando o valor salvo muda (ex.: restaurar).
            key: ValueKey(s.defaultPassword),
            current: s.defaultPassword,
            onSave: (v) => c.update(s.copyWith(defaultPassword: v)),
          ),
          SettingCard(
            title: 'Tempo limite por etapa',
            subtitle: 'Conectar, autenticar e enviar o comando',
            child: _IntSlider(
              value: s.timeoutSeconds,
              range: AppSettings.timeoutRange,
              unit: 's',
              onChanged: (v) => c.update(s.copyWith(timeoutSeconds: v)),
            ),
          ),
          SettingCard(
            title: 'Novas tentativas',
            subtitle: 'Antes de marcar a bicicleta como Falha',
            child: _IntChoices(
              value: s.retries,
              range: AppSettings.retriesRange,
              onSelected: (v) => c.update(s.copyWith(retries: v)),
            ),
          ),
          const SectionTitle('Operação'),
          SettingCard(
            title: 'Marcha alvo',
            subtitle: 'Enviada a cada bicicleta (+MODE=${s.targetGear})',
            child: _IntChoices(
              value: s.targetGear,
              range: AppSettings.gearRange,
              onSelected: (v) => c.update(s.copyWith(targetGear: v)),
            ),
          ),
          SettingCard(
            title: 'Travar a bike',
            subtitle: 'Depois da marcha, envia +LOCK=1 às que tiverem trava',
            child: Row(
              children: [
                Expanded(child: Text(s.lockBikes ? 'Ligado' : 'Desligado')),
                Switch(
                  value: s.lockBikes,
                  onChanged: (v) => c.update(s.copyWith(lockBikes: v)),
                ),
              ],
            ),
          ),
          const SectionTitle('Bicicletas bloqueadas'),
          const _BlocklistCard(),
          const SectionTitle('Desenvolvimento'),
          SettingCard(
            title: 'Modo simulação',
            subtitle:
                'Usa bicicletas fictícias (com falhas aleatórias) no lugar do '
                'Bluetooth. Nenhum comando é enviado.',
            child: Row(
              children: [
                Expanded(child: Text(s.useMock ? 'Ligado' : 'Desligado')),
                Switch(
                  value: s.useMock,
                  onChanged: (v) => c.update(s.copyWith(useMock: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bikes que a operação pula. Bloqueie pelo cartão na aba Bicicletas.
class _BlocklistCard extends ConsumerWidget {
  const _BlocklistCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(fleetBlocklistProvider);
    final entries = blocked.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: entries.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma bicicleta bloqueada. Para bloquear, toque em '
                  '"Bloquear" no cartão da bike na aba Bicicletas.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            : Column(
                children: [
                  for (final e in entries)
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(
                        e.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        e.key,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remover da lista',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(fleetBlocklistProvider.notifier)
                            .unblock(e.key),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  const _PasswordCard({super.key, required this.current, required this.onSave});

  final String current;
  final Future<void> Function(String) onSave;

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  late final _ctrl = TextEditingController(text: widget.current);
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valid => AppSettings.isValidPassword(_ctrl.text);
  bool get _changed => _ctrl.text != widget.current;

  @override
  Widget build(BuildContext context) {
    return SettingCard(
      title: 'Senha padrão',
      subtitle: 'Senha Bluetooth de 6 dígitos tentada em cada bicicleta',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                errorText: _ctrl.text.isEmpty || _valid
                    ? null
                    : 'Use 6 dígitos',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.text,
            ),
            onPressed: _valid && _changed
                ? () async {
                    await widget.onSave(_ctrl.text);
                    if (!context.mounted) return;
                    FocusScope.of(context).unfocus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Senha padrão salva.')),
                    );
                  }
                : null,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _IntChoices extends StatelessWidget {
  const _IntChoices({
    required this.value,
    required this.range,
    required this.onSelected,
  });

  final int value;
  final ({int min, int max}) range;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = range.min; i <= range.max; i++)
          ChoiceChip(
            label: Text('$i'),
            selected: value == i,
            selectedColor: AppColors.yellow,
            onSelected: (_) => onSelected(i),
          ),
      ],
    );
  }
}

class _IntSlider extends StatefulWidget {
  const _IntSlider({
    required this.value,
    required this.range,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final ({int min, int max}) range;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<_IntSlider> createState() => _IntSliderState();
}

class _IntSliderState extends State<_IntSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final v = _dragging ?? widget.value.toDouble();
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: v,
            min: widget.range.min.toDouble(),
            max: widget.range.max.toDouble(),
            divisions: widget.range.max - widget.range.min,
            activeColor: AppColors.yellow,
            label: '${v.round()} ${widget.unit}',
            onChanged: (x) => setState(() => _dragging = x),
            onChangeEnd: (x) {
              setState(() => _dragging = null);
              widget.onChanged(x.round());
            },
          ),
        ),
        SizedBox(
          width: 48,
          child: Text('${v.round()} ${widget.unit}', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
