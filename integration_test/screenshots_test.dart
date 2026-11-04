// Gera as imagens do README rodando o app com dados simulados.
//
//   flutter drive \
//     --driver=test_driver/screenshots.dart \
//     --target=integration_test/screenshots_test.dart \
//     -d <simulador>
//
// As telas usam um cenário fixo (bikes concluídas, uma falha e uma
// bloqueada). Nenhum Bluetooth é usado.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inow_jbrake/app.dart';
import 'package:inow_jbrake/core/services/screen_awake.dart';
import 'package:inow_jbrake/core/services/success_sound.dart';
import 'package:inow_jbrake/features/app_settings/data/datasources/app_settings_local_datasource.dart';
import 'package:inow_jbrake/features/app_settings/domain/entities/app_settings.dart';
import 'package:inow_jbrake/features/app_settings/presentation/providers/app_settings_providers.dart';
import 'package:inow_jbrake/features/bike/data/datasources/bike_local_datasource.dart';
import 'package:inow_jbrake/features/bike/presentation/providers/bike_providers.dart';
import 'package:inow_jbrake/features/fleet/data/datasources/fleet_blocklist_local_datasource.dart';
import 'package:inow_jbrake/features/fleet/domain/entities/fleet_bike.dart';
import 'package:inow_jbrake/features/fleet/domain/gateways/bike_fleet_gateway.dart';
import 'package:inow_jbrake/features/fleet/presentation/providers/fleet_blocklist_providers.dart';
import 'package:inow_jbrake/features/fleet/presentation/providers/fleet_providers.dart';

class _Settings extends AppSettingsLocalDataSource {
  AppSettings value = const AppSettings(useMock: true);

  @override
  AppSettings load() => value;

  @override
  Future<void> save(AppSettings s) async => value = s;
}

class _Blocklist extends FleetBlocklistLocalDataSource {
  final saved = <String, String>{'C4:7F:51:0A:12:05': 'INOW-0105'};

  @override
  Map<String, String> load() => {...saved};

  @override
  Future<void> add(String id, String name) async => saved[id] = name;

  @override
  Future<void> remove(String id) async => saved.remove(id);
}

class _SavedBike extends BikeLocalDataSource {
  @override
  ({String id, String name})? get lastBike =>
      (id: 'C4:7F:51:0A:12:01', name: 'INOW-0101');
}

class _NoScreen implements ScreenAwake {
  @override
  Future<void> set({required bool on}) async {}
}

class _NoSound implements SuccessSound {
  @override
  Future<void> play(String key) async {}
}

/// Resultado fixo, sem Bluetooth: tudo conclui, menos a 0104 (senha recusada).
class _DemoGateway implements BikeFleetGateway {
  static const _delay = Duration(milliseconds: 60);
  static const _fleet = [
    FleetBike(id: 'C4:7F:51:0A:12:01', name: 'INOW-0101', rssi: -48),
    FleetBike(id: 'C4:7F:51:0A:12:02', name: 'INOW-0102', rssi: -55),
    FleetBike(id: 'C4:7F:51:0A:12:03', name: 'INOW-0103', rssi: -63),
    FleetBike(id: 'C4:7F:51:0A:12:04', name: 'INOW-0104', rssi: -71),
    FleetBike(id: 'C4:7F:51:0A:12:05', name: 'INOW-0105', rssi: -78),
  ];
  static const _fail = 'C4:7F:51:0A:12:04';

  StreamController<List<FleetBike>>? _scan;

  @override
  Stream<List<FleetBike>> discover() {
    final c = _scan = StreamController<List<FleetBike>>();
    Future<void>.delayed(_delay, () {
      if (!c.isClosed) c.add(_fleet);
    });
    return c.stream;
  }

  @override
  Future<void> stopDiscovery() async => _scan?.close();

  @override
  Future<void> connect(String id) => Future<void>.delayed(_delay);

  @override
  Future<void> authenticate(String id, String password) async {
    await Future<void>.delayed(_delay);
    if (id == _fail) throw const FleetFailure('Senha recusada (CODE_NG).');
  }

  @override
  Future<FleetBikeDetails> identify(String id) async {
    await Future<void>.delayed(_delay);
    final noLock = id.endsWith('03');
    return FleetBikeDetails(
      model: id.endsWith('02') ? 'imoogoo-inow07' : 'imoogoo-inow05',
      features: [
        BikeFeature.gear,
        if (!noLock) BikeFeature.lock,
        BikeFeature.headlight,
      ],
    );
  }

  @override
  Future<void> setGear(String id, int level) => Future<void>.delayed(_delay);

  @override
  Future<void> lock(String id) => Future<void>.delayed(_delay);

  @override
  Future<void> disconnect(String id) => Future<void>.delayed(_delay);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captura as telas', (tester) async {
    await binding.convertFlutterSurfaceToImage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsLocalProvider.overrideWithValue(_Settings()),
          fleetBlocklistLocalProvider.overrideWithValue(_Blocklist()),
          bikeLocalProvider.overrideWithValue(_SavedBike()),
          screenAwakeProvider.overrideWithValue(_NoScreen()),
          successSoundProvider.overrideWithValue(_NoSound()),
          bikeFleetGatewayProvider.overrideWithValue(_DemoGateway()),
          fleetScanQuietPeriodProvider.overrideWithValue(
            const Duration(milliseconds: 300),
          ),
        ],
        child: const InowJbrakeApp(),
      ),
    );

    Future<void> settle(Finder until, {int maxMs = 8000}) async {
      for (var waited = 0; waited < maxMs; waited += 100) {
        await tester.pump(const Duration(milliseconds: 100));
        if (until.evaluate().isNotEmpty) return;
      }
    }

    // Veículo (tela inicial) com uma bike salva.
    await settle(find.text('INOW-0101'));
    await binding.takeScreenshot('03-veiculo');

    // Bicicletas: deixa a busca terminar e roda a operação.
    await tester.tap(find.text('Bicicletas'));
    await settle(find.text('Iniciar operação'));
    await tester.tap(find.text('Iniciar operação'));
    await settle(find.text('Parada'), maxMs: 15000);
    // Volta ao topo para mostrar o cartão de operação.
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 1500),
      3000,
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-bicicletas');

    // Configurações.
    await tester.tap(find.byTooltip('Configurações'));
    await settle(find.text('Marcha alvo'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-configuracoes');
  });
}
