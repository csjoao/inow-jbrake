import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/bike_providers.dart';

/// Tudo que entra e sai pelo Bluetooth + campo para mandar comandos à mão.
/// Feito para testes: descobrir o formato da telemetria, novos comandos etc.
class ConsoleScreen extends ConsumerStatefulWidget {
  const ConsoleScreen({super.key});

  @override
  ConsumerState<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends ConsumerState<ConsoleScreen> {
  final _input = TextEditingController();
  bool _hideTelemetry = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? _input.text).trim();
    if (t.isEmpty) return;
    await ref.read(bikeControllerProvider.notifier).sendRaw(t);
    if (text == null) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    var log = ref.watch(bikeLogProvider);
    final format = ref.watch(
      bikeControllerProvider.select((s) => s.telemetryFormats),
    );
    if (_hideTelemetry) {
      // Pacotes binários aparecem em hex (com espaços); texto não.
      log = log.where((l) => l.outgoing || !l.text.contains(' ')).toList();
    }
    final reversed = log.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Console'),
        actions: [
          IconButton(
            tooltip: 'Ocultar telemetria',
            icon: Icon(
              _hideTelemetry ? Icons.filter_alt : Icons.filter_alt_off,
            ),
            onPressed: () => setState(() => _hideTelemetry = !_hideTelemetry),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: ref.read(bikeLogProvider.notifier).clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: Text(
              'Pacotes binários reconhecidos: '
              '${format.isEmpty ? "nenhum ainda" : format.join(", ")}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: reversed.length,
              itemBuilder: (_, i) {
                final l = reversed[i];
                final t = l.at;
                final ts =
                    '${t.hour.toString().padLeft(2, '0')}:'
                    '${t.minute.toString().padLeft(2, '0')}:'
                    '${t.second.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: SelectableText(
                    '$ts ${l.outgoing ? "→" : "←"} ${l.text}',
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 12,
                      color: l.outgoing ? Colors.blue.shade700 : Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final cmd in const [
                  'GETDEVID',
                  '+VER?',
                  '+MODE=?',
                  '+MDMX=?',
                  '+LOCK=?',
                  '+UNIT=?',
                  '+CRZE=?',
                  '+BRAKE=?',
                  'HLGT=?',
                  '+SPLT=?',
                  '+STBY=?',
                  '+MPMD=?',
                  '+RFRP=?',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(cmd),
                      onPressed: () => _send(cmd),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: '+COMANDO=valor',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
