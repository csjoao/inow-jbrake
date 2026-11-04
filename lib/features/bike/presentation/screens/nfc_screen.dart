import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/bike_state.dart';
import '../providers/bike_providers.dart';

/// Cartões NFC que destravam a bike (`NfcActivity` do app oficial).
class NfcScreen extends ConsumerStatefulWidget {
  const NfcScreen({super.key});

  @override
  ConsumerState<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends ConsumerState<NfcScreen> {
  late final BikeController _c = ref.read(bikeControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(_c.refreshNfcCards());
  }

  @override
  void dispose() {
    if (ref.read(bikeControllerProvider).nfcPairing == NfcPairing.waitingCard) {
      unawaited(_c.stopNfcPairing());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(bikeControllerProvider);
    final pairing = s.nfcPairing;

    final status = switch (pairing) {
      NfcPairing.idle => null,
      NfcPairing.waitingCard => 'Encoste o cartão no leitor da bike...',
      NfcPairing.success => 'Cartão cadastrado!',
      NfcPairing.alreadyBound => 'Esse cartão já estava cadastrado.',
      NfcPairing.failed => 'Não foi possível ler o cartão.',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões NFC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _c.refreshNfcCards,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.nfc,
                    size: 64,
                    color: pairing == NfcPairing.waitingCard
                        ? AppColors.yellow
                        : AppColors.muted,
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 12),
                    Text(status, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 16),
                  if (pairing == NfcPairing.waitingCard)
                    OutlinedButton(
                      onPressed: _c.stopNfcPairing,
                      child: const Text('Cancelar'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: s.isConnected ? _c.startNfcPairing : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar cartão'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Cartões cadastrados',
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
          ),
          if (s.nfcCards.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nenhum cartão.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          for (final id in s.nfcCards)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: Text('Cartão $id'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remover cartão $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) await _c.deleteNfcCard(id);
  }
}
