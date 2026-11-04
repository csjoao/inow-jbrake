import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/protocol/inow_commands.dart';
import '../providers/bike_providers.dart';
import '../widgets/section.dart';

/// Senhas e nome do Bluetooth (ChangeBleInfo, ChangeLockPwd, ChangeGearPwd).
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(bikeControllerProvider.notifier)
          .sendRaw(InowCommands.gearPasswordQuery),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(bikeControllerProvider);
    final c = ref.read(bikeControllerProvider.notifier);
    final gearPwd = s.values['FCPWRD'];

    return Scaffold(
      appBar: AppBar(title: const Text('Senhas e Bluetooth')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Bluetooth'),
          NavTile(
            icon: Icons.edit,
            title: 'Nome da bike',
            subtitle: s.name,
            onTap: () async {
              final v = await _ask(
                title: 'Novo nome',
                initial: s.name ?? '',
                numeric: false,
              );
              if (v == null) return;
              await c.renameBike(v);
              _toast('Nome enviado. Pode precisar religar a bike.');
            },
          ),
          NavTile(
            icon: Icons.bluetooth,
            title: 'Senha de conexão',
            subtitle: '6 dígitos — usada ao conectar (padrão 000000)',
            onTap: () async {
              final v = await _ask(
                title: 'Nova senha de conexão',
                length: 6,
                confirm: true,
              );
              if (v == null) return;
              await c.changeBlePassword(v);
              _toast('Senha alterada e salva neste celular.');
            },
          ),
          const SectionTitle('Bike'),
          NavTile(
            icon: Icons.lock_outline,
            title: 'Senha da trava',
            onTap: () async {
              final v = await _ask(title: 'Nova senha da trava', confirm: true);
              if (v == null) return;
              await c.sendRaw(InowCommands.lockPassword(v));
              _toast('Senha da trava enviada.');
            },
          ),
          NavTile(
            icon: Icons.speed,
            title: 'Senha de marcha',
            subtitle: gearPwd == null ? '4 dígitos' : 'atual: $gearPwd',
            onTap: () async {
              final v = await _ask(
                title: 'Nova senha de marcha',
                length: 4,
                confirm: true,
              );
              if (v == null) return;
              await c.setAndQuery(
                InowCommands.gearPassword(v),
                InowCommands.gearPasswordQuery,
              );
              _toast('Senha de marcha enviada.');
            },
          ),
        ],
      ),
    );
  }

  /// Pede um valor. Com [confirm], pede duas vezes e confere.
  Future<String?> _ask({
    required String title,
    String initial = '',
    int? length,
    bool numeric = true,
    bool confirm = false,
  }) {
    final a = TextEditingController(text: initial);
    final b = TextEditingController();
    String? error;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          InputDecoration deco(String hint) => InputDecoration(
            hintText: hint,
            errorText: (!confirm || hint == 'Confirmar') ? error : null,
            counterText: '',
          );
          final formatters = numeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : <TextInputFormatter>[];

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: a,
                  autofocus: true,
                  maxLength: length ?? (numeric ? 8 : 20),
                  keyboardType: numeric ? TextInputType.number : null,
                  inputFormatters: formatters,
                  decoration: deco(
                    length == null ? 'Novo valor' : '$length dígitos',
                  ),
                ),
                if (confirm)
                  TextField(
                    controller: b,
                    maxLength: length ?? 8,
                    keyboardType: numeric ? TextInputType.number : null,
                    inputFormatters: formatters,
                    decoration: deco('Confirmar'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final v = a.text.trim();
                  if (v.isEmpty) return;
                  if (length != null && v.length != length) {
                    setLocal(() => error = 'Precisa ter $length dígitos');
                    return;
                  }
                  if (confirm && v != b.text.trim()) {
                    setLocal(() => error = 'Os valores não batem');
                    return;
                  }
                  Navigator.pop(ctx, v);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
