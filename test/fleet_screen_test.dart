import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inow_jbrake/app.dart';
import 'package:inow_jbrake/core/services/screen_awake.dart';
import 'package:inow_jbrake/features/app_settings/data/datasources/app_settings_local_datasource.dart';
import 'package:inow_jbrake/features/app_settings/domain/entities/app_settings.dart';
import 'package:inow_jbrake/features/app_settings/presentation/providers/app_settings_providers.dart';
import 'package:inow_jbrake/features/app_settings/presentation/screens/app_settings_screen.dart';
import 'package:inow_jbrake/features/bike/data/datasources/bike_local_datasource.dart';
import 'package:inow_jbrake/features/bike/presentation/providers/bike_providers.dart';
import 'package:inow_jbrake/features/fleet/data/datasources/fleet_blocklist_local_datasource.dart';
import 'package:inow_jbrake/features/fleet/data/gateways/mock_bike_fleet_gateway.dart';
import 'package:inow_jbrake/features/fleet/domain/entities/fleet_bike.dart';
import 'package:inow_jbrake/features/fleet/presentation/providers/fleet_blocklist_providers.dart';
import 'package:inow_jbrake/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:inow_jbrake/features/fleet/presentation/screens/fleet_screen.dart';
import 'package:inow_jbrake/features/fleet/presentation/widgets/fleet_bike_card.dart';

class _NoBikeLocal extends BikeLocalDataSource {
  @override
  ({String id, String name})? get lastBike => null;
}

class _MemoryBlocklist extends FleetBlocklistLocalDataSource {
  final saved = <String, String>{};

  @override
  Map<String, String> load() => {...saved};

  @override
  Future<void> add(String id, String name) async => saved[id] = name;

  @override
  Future<void> remove(String id) async => saved.remove(id);
}

class _FakeScreen implements ScreenAwake {
  final calls = <bool>[];

  @override
  Future<void> set({required bool on}) async => calls.add(on);
}

class _MemorySettings extends AppSettingsLocalDataSource {
  AppSettings value = const AppSettings();

  @override
  AppSettings load() => value;

  @override
  Future<void> save(AppSettings s) async => value = s;
}

void main() {
  testWidgets('aba Bicicletas: lista, operação e configurações', (t) async {
    final screen = _FakeScreen();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          bikeLocalProvider.overrideWithValue(_NoBikeLocal()),
          screenAwakeProvider.overrideWithValue(screen),
          fleetBlocklistLocalProvider.overrideWithValue(_MemoryBlocklist()),
          appSettingsLocalProvider.overrideWithValue(_MemorySettings()),
          fleetScanQuietPeriodProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
          bikeFleetGatewayProvider.overrideWithValue(
            MockBikeFleetGateway(
              stepDelay: const Duration(milliseconds: 10),
              failureRate: 0,
            ),
          ),
        ],
        child: const InowJbrakeApp(),
      ),
    );

    await t.tap(find.text('Bicicletas'));
    // A busca simulada acha uma bike a cada 10 ms (o indicador gira, então
    // sem pumpAndSettle).
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.textContaining('Bicicletas encontradas'), findsOneWidget);
    expect(find.text('Desconectada'), findsWidgets);
    expect(find.text('Parada'), findsOneWidget);

    // Bloquear pelo cartão: a tag muda e o botão vira "Desbloquear".
    await t.ensureVisible(find.text('Bloquear').first);
    await t.pump();
    await t.tap(find.text('Bloquear').first);
    await t.pump();
    expect(find.text('Bloqueada'), findsOneWidget);
    expect(find.text('Desbloquear'), findsOneWidget);
    await t.ensureVisible(find.text('Desbloquear'));
    await t.pump();
    await t.tap(find.text('Desbloquear'));
    await t.pump();
    expect(find.text('Bloqueada'), findsNothing);

    // Liga "Manter tela ligada": nada muda até a operação começar.
    await t.ensureVisible(find.text('Manter tela ligada'));
    await t.pump();
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(screen.calls, isEmpty);

    await t.ensureVisible(find.text('Iniciar operação'));
    await t.pump();
    await t.tap(find.text('Iniciar operação'));
    await t.pump();
    // Sempre do zero: lista limpa e busca nova antes de acionar.
    expect(find.text('Buscando bicicletas…'), findsWidgets);
    expect(find.byType(FleetBikeCard), findsNothing);
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('Em execução'), findsOneWidget);
    expect(screen.calls, [true]);

    // Deixa a operação terminar (o indicador pulsa, então sem pumpAndSettle).
    for (var i = 0; i < 300; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('Parada'), findsOneWidget);
    expect(screen.calls, [true, false]);
    expect(find.text('Desconectada'), findsNothing);
    // A lista rolou acompanhando as bikes acionadas.
    final list = t.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(FleetScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(list.position.pixels, greaterThan(0));
    await t.scrollUntilVisible(find.text('Operação concluída').last, 200);
    expect(find.text('Operação concluída'), findsWidgets);

    await t.tap(find.byTooltip('Configurações'));
    await t.pumpAndSettle();
    expect(find.text('Tempo máximo de busca'), findsOneWidget);
    expect(find.text('Senha padrão'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Marcha alvo'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(AppSettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Marcha alvo'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Deslizar do meio da tela para a direita volta para a lista.
    await t.flingFrom(const Offset(400, 300), const Offset(300, 0), 1000);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppSettingsScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('operação contínua mostra uma quebra por ciclo', (t) async {
    final gateway = MockBikeFleetGateway(
      stepDelay: const Duration(milliseconds: 10),
      failureRate: 0,
      growFleet: false,
      fleet: const [
        FleetBike(id: 'X:01', name: 'INOW-X1'),
        FleetBike(id: 'X:02', name: 'INOW-X2'),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          bikeLocalProvider.overrideWithValue(_NoBikeLocal()),
          screenAwakeProvider.overrideWithValue(_FakeScreen()),
          fleetBlocklistLocalProvider.overrideWithValue(_MemoryBlocklist()),
          appSettingsLocalProvider.overrideWithValue(_MemorySettings()),
          fleetScanQuietPeriodProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
          bikeFleetGatewayProvider.overrideWithValue(gateway),
        ],
        child: const InowJbrakeApp(),
      ),
    );
    await t.tap(find.text('Bicicletas'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }

    await t.ensureVisible(find.text('Iniciar operação contínua'));
    await t.pump();
    await t.tap(find.text('Iniciar operação contínua'));
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('Ciclo 1'), findsOneWidget);
    expect(find.textContaining('Histórico por ciclo'), findsOneWidget);
    // As duas bikes foram concluídas no ciclo 1; ciclos seguintes vazios
    // não criam novas quebras.
    expect(find.text('Ciclo 2'), findsNothing);
    expect(find.textContaining('nada novo'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Ciclos? 2(\D|$)')), findsOneWidget);
    expect(find.text('Operação concluída'), findsNWidgets(2));

    await t.ensureVisible(find.text('Parar operação'));
    await t.pump();
    await t.tap(find.text('Parar operação'));
    await t.pump();
    expect(find.text('Parada'), findsOneWidget);
    expect(find.text('Ciclo 1'), findsOneWidget);
    // Deixa terminar a etapa simulada que o "Parar" abandonou.
    await t.pump(const Duration(milliseconds: 100));
  });
}
