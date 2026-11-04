import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/bike_state.dart';
import '../providers/bike_providers.dart';

/// Aba "Veículo" do app oficial: bike salva ou cartão "Adicionar".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bike = ref.watch(bikeControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFE0E0E0),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    AppConstants.appName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 30),
                  color: AppColors.muted,
                  onPressed: () => context.push(AppRoutes.scan),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Veículo',
              style: TextStyle(fontSize: 22, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (bike.deviceId == null)
              const _AddBikeCard()
            else
              _SavedBikeCard(bike: bike),
          ],
        ),
      ),
    );
  }
}

class _AddBikeCard extends StatelessWidget {
  const _AddBikeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nenhum veículo\nadicionado',
                    style: TextStyle(fontSize: 20, color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => context.push(AppRoutes.scan),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.yellow,
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Adicionar'),
                  ),
                ],
              ),
            ),
            const Icon(Icons.electric_bike, size: 96, color: Color(0xFF8D6E63)),
          ],
        ),
      ),
    );
  }
}

class _SavedBikeCard extends ConsumerWidget {
  const _SavedBikeCard({required this.bike});

  final BikeState bike;

  /// Desconecta e apaga a bike e a senha salvas no aparelho.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir veículo?'),
        content: Text(
          '${bike.name ?? 'A bike'} e a senha salva serão removidas deste '
          'aparelho. Para usar de novo, adicione pela busca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(bikeControllerProvider.notifier).forgetBike();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Veículo excluído.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = bike.isConnected;
    final busy =
        bike.phase == BikePhase.connecting ||
        bike.phase == BikePhase.authenticating;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(connected ? AppRoutes.bike : AppRoutes.scan),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bike.name ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      connected
                          ? 'Conectado com sucesso'
                          : busy
                          ? 'Conectando...'
                          : 'Desconectado — toque para conectar',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.bluetooth,
                color: connected ? AppColors.yellow : AppColors.muted,
                size: 32,
              ),
              IconButton(
                tooltip: 'Excluir veículo',
                icon: const Icon(Icons.delete_outline),
                color: AppColors.muted,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
