import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/bike_ble_datasource.dart';
import '../providers/bike_providers.dart';
import '../widgets/password_dialog.dart';

/// "Adicionar veículo": procura bikes e conecta com a senha.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  bool _connecting = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _select(ScannedBike bike) async {
    final controller = ref.read(bikeControllerProvider.notifier);
    final pwd = await showPasswordDialog(
      context,
      initial:
          controller.savedPasswordFor(bike.id) ?? AppConstants.defaultPassword,
    );
    if (pwd == null || !mounted) return;

    setState(() => _connecting = true);
    final error = await controller.connect(bike, pwd);
    if (!mounted) return;
    setState(() => _connecting = false);

    if (error == null) {
      context.pushReplacement(AppRoutes.bike);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      ref.invalidate(scanResultsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(scanResultsProvider);
    final scanning = ref.watch(isScanningProvider).value ?? false;
    final bikes = results.value ?? const <ScannedBike>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar veículo'),
        actions: [
          if (!scanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(scanResultsProvider),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 48),
              RotationTransition(
                turns: _spin,
                child: const SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: 0.75,
                    color: AppColors.yellow,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                scanning ? 'Pesquisando...' : 'Pesquisa concluída',
                style: const TextStyle(color: AppColors.yellow, fontSize: 18),
              ),
              if (results.hasError)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro no Bluetooth: ${results.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bikes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final b = bikes[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: const Icon(
                          Icons.electric_bike,
                          color: AppColors.yellow,
                          size: 32,
                        ),
                        title: Text(
                          b.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${b.id}  •  ${b.rssi} dBm'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _connecting ? null : () => _select(b),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 8, 32, 32),
                child: Text(
                  'Verifique se a bike está ligada e perto do celular',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          ),
          if (_connecting)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.yellow),
                        SizedBox(height: 16),
                        Text('Conectando...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
