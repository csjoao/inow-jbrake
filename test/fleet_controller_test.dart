import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inow_jbrake/core/constants/app_constants.dart';
import 'package:inow_jbrake/features/app_settings/domain/entities/app_settings.dart';
import 'package:inow_jbrake/features/app_settings/presentation/providers/app_settings_providers.dart';
import 'package:inow_jbrake/features/bike/presentation/providers/bike_providers.dart';
import 'package:inow_jbrake/features/fleet/data/gateways/ble_bike_fleet_gateway.dart';
import 'package:inow_jbrake/features/fleet/data/gateways/mock_bike_fleet_gateway.dart';
import 'package:inow_jbrake/features/fleet/domain/entities/fleet_bike.dart';
import 'package:inow_jbrake/features/fleet/domain/gateways/bike_fleet_gateway.dart';
import 'package:inow_jbrake/features/fleet/presentation/providers/fleet_blocklist_providers.dart';
import 'package:inow_jbrake/core/services/success_sound.dart';
import 'package:inow_jbrake/features/fleet/presentation/providers/fleet_providers.dart';

import 'helpers/fakes.dart';

class _FakeGateway implements BikeFleetGateway {
  _FakeGateway(this.bikes);

  /// Bikes que a busca "encontra" (todas de uma vez).
  List<FleetBike> bikes;
  final calls = <String>[];
  StreamController<List<FleetBike>>? scan;
  int stopDiscoveryCalls = 0;

  /// id → etapa que falha (`connect`, `auth`, `gear`).
  final failAt = <String, String>{};

  /// Bikes que respondem como se tivessem trava.
  final withLock = <String>{};

  /// Se definidos, `connect`/`setGear` esperam (para testar o "Parar").
  Completer<void>? connectGate;
  Completer<void>? gearGate;

  @override
  Stream<List<FleetBike>> discover() {
    final c = scan = StreamController<List<FleetBike>>();
    if (bikes.isNotEmpty) scheduleMicrotask(() => c.add(bikes));
    return c.stream;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalls++;
    await scan?.close();
  }

  @override
  Future<void> connect(String id) async {
    calls.add('connect $id');
    await connectGate?.future;
    if (failAt[id] == 'connect') throw const FleetFailure('sem resposta');
  }

  @override
  Future<void> authenticate(String id, String password) async {
    calls.add('auth $id $password');
    if (failAt[id] == 'auth') throw const FleetFailure('senha recusada');
  }

  @override
  Future<FleetBikeDetails> identify(String id) async {
    calls.add('identify $id');
    return FleetBikeDetails(
      model: 'imoogoo-inow05',
      features: [BikeFeature.gear, if (withLock.contains(id)) BikeFeature.lock],
    );
  }

  @override
  Future<void> setGear(String id, int level) async {
    calls.add('gear $id $level');
    await gearGate?.future;
    if (failAt[id] == 'gear') throw const FleetFailure('sem confirmação');
  }

  @override
  Future<void> lock(String id) async {
    calls.add('lock $id');
    if (failAt[id] == 'lock') throw const FleetFailure('não travou');
  }

  @override
  Future<void> disconnect(String id) async => calls.add('disconnect $id');
}

const _bikes = [
  FleetBike(id: 'A', name: 'Bike A'),
  FleetBike(id: 'B', name: 'Bike B'),
  FleetBike(id: 'C', name: 'Bike C'),
];

const _quiet = Duration(milliseconds: 20);

Future<(ProviderContainer, _FakeGateway)> _setup({
  AppSettings settings = const AppSettings(retries: 0, scanSeconds: 1),
  List<FleetBike> bikes = _bikes,
  Map<String, String> blocked = const {},
}) async {
  final gw = _FakeGateway(bikes);
  final blocklist = MemoryBlocklist()..saved.addAll(blocked);
  final container = ProviderContainer(
    overrides: [
      fleetBlocklistLocalProvider.overrideWithValue(blocklist),
      bikeFleetGatewayProvider.overrideWithValue(gw),
      fleetScanQuietPeriodProvider.overrideWithValue(_quiet),
      appSettingsLocalProvider.overrideWithValue(MemorySettings(settings)),
      bikeLocalProvider.overrideWithValue(NoBikeLocal()),
      successSoundProvider.overrideWithValue(FakeSuccessSound()),
    ],
  );
  addTearDown(container.dispose);
  container.read(fleetControllerProvider);
  // Busca inicial: com bikes termina após o período de silêncio.
  if (bikes.isNotEmpty) await _until(container, (s) => !s.isRefreshing);
  return (container, gw);
}

Future<void> _until(ProviderContainer c, bool Function(FleetState) test) async {
  final sw = Stopwatch()..start();
  while (!test(c.read(fleetControllerProvider))) {
    if (sw.elapsed > const Duration(seconds: 3)) fail('timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

FleetBike _bike(ProviderContainer c, String id) =>
    c.read(fleetControllerProvider).bikes.firstWhere((b) => b.id == id);

FleetBikeStatus _status(ProviderContainer c, String id) => _bike(c, id).status;

void main() {
  test('busca ao abrir e para depois do período sem bike nova', () async {
    final (c, gw) = await _setup();
    final s = c.read(fleetControllerProvider);
    expect(s.bikes.map((b) => b.id), ['A', 'B', 'C']);
    expect(
      s.bikes.every((b) => b.status == FleetBikeStatus.disconnected),
      isTrue,
    );
    expect(gw.stopDiscoveryCalls, 1);
  });

  test('sem bikes, continua buscando até o tempo limite', () async {
    final (c, gw) = await _setup(bikes: const []);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.read(fleetControllerProvider).isRefreshing, isTrue);

    // Uma bike aparece no meio da busca: termina após o silêncio, não no limite.
    gw.scan!.add([_bikes.first]);
    await _until(c, (s) => !s.isRefreshing);
    expect(c.read(fleetControllerProvider).bikes, hasLength(1));
  });

  test('iniciar sem bikes busca e avisa quando não acha nenhuma', () async {
    final (c, gw) = await _setup(bikes: const []);
    final sw = Stopwatch()..start();
    await c.read(fleetControllerProvider.notifier).start();

    expect(sw.elapsed, greaterThan(const Duration(milliseconds: 900)));
    final s = c.read(fleetControllerProvider);
    expect(s.isRunning, isFalse);
    expect(s.summary, 'Nenhuma bicicleta encontrada em 1 s.');
    expect(gw.calls, isEmpty);
  });

  test('processa uma bike por vez com senha e marcha configuradas', () async {
    final (c, gw) = await _setup(
      settings: const AppSettings(
        defaultPassword: '123456',
        targetGear: 0,
        retries: 0,
      ),
    );
    await c.read(fleetControllerProvider.notifier).start();

    expect(gw.calls.take(5), [
      'connect A',
      'auth A 123456',
      'identify A',
      'gear A 0',
      'disconnect A',
    ]);
    for (final id in ['A', 'B', 'C']) {
      expect(_status(c, id), FleetBikeStatus.completed);
    }
    expect(_bike(c, 'A').model, 'imoogoo-inow05');
    expect(_bike(c, 'A').features, [BikeFeature.gear]);
    final s = c.read(fleetControllerProvider);
    expect(s.isRunning, isFalse);
    expect(s.processed, 3);
  });

  test('trava só as bikes que têm trava', () async {
    final (c, gw) = await _setup();
    gw.withLock.add('A');
    await c.read(fleetControllerProvider.notifier).start();

    expect(gw.calls.take(6), [
      'connect A',
      'auth A 000000',
      'identify A',
      'gear A 0',
      'lock A',
      'disconnect A',
    ]);
    expect(gw.calls, isNot(contains('lock B')));
    expect(_bike(c, 'A').message, 'Marcha ajustada para 0 e bike travada.');
    expect(_bike(c, 'B').message, 'Marcha ajustada para 0 (sem trava).');
    expect(_status(c, 'B'), FleetBikeStatus.completed);
  });

  test('com "Travar" desligado, não trava nem quem tem trava', () async {
    final (c, gw) = await _setup(
      settings: const AppSettings(retries: 0, scanSeconds: 1, lockBikes: false),
    );
    gw.withLock.add('A');
    await c.read(fleetControllerProvider.notifier).start();
    expect(gw.calls, isNot(contains('lock A')));
    expect(_status(c, 'A'), FleetBikeStatus.completed);
    expect(_bike(c, 'A').message, 'Marcha ajustada para 0.');
  });

  test('falha ao travar marca Falha', () async {
    final (c, gw) = await _setup();
    gw
      ..withLock.add('A')
      ..failAt['A'] = 'lock';
    await c.read(fleetControllerProvider.notifier).start();
    expect(_status(c, 'A'), FleetBikeStatus.failed);
    expect(_bike(c, 'A').message, 'não travou');
    expect(gw.calls, contains('disconnect A'));
  });

  test('falha marca a bike, desconecta e segue para a próxima', () async {
    final (c, gw) = await _setup();
    gw.failAt['B'] = 'auth';
    await c.read(fleetControllerProvider.notifier).start();

    expect(_status(c, 'A'), FleetBikeStatus.completed);
    expect(_status(c, 'B'), FleetBikeStatus.failed);
    expect(_bike(c, 'B').message, 'senha recusada');
    expect(_status(c, 'C'), FleetBikeStatus.completed);
    expect(gw.calls, contains('disconnect B'));
    expect(gw.calls, isNot(contains('gear B 0')));
  });

  test('falha ao conectar também cancela a conexão pendente', () async {
    final (c, gw) = await _setup();
    gw.failAt['A'] = 'connect';
    await c.read(fleetControllerProvider.notifier).start();
    expect(gw.calls.take(2), ['connect A', 'disconnect A']);
  });

  test('tenta de novo antes de marcar falha', () async {
    final (c, gw) = await _setup(
      settings: const AppSettings(retries: 2, scanSeconds: 1),
    );
    gw.failAt['A'] = 'connect';
    await c.read(fleetControllerProvider.notifier).start();

    expect(gw.calls.where((x) => x == 'connect A'), hasLength(3));
    expect(_status(c, 'A'), FleetBikeStatus.failed);
  });

  test('parar abandona a etapa na hora e desconecta a bike ativa', () async {
    final (c, gw) = await _setup();
    gw.gearGate = Completer<void>(); // nunca responde
    final ctrl = c.read(fleetControllerProvider.notifier);

    final run = ctrl.start();
    await _until(c, (s) => s.activeStep == FleetStep.settingGear);

    ctrl.stop();
    // A tela já mostra parada, sem esperar o tempo limite.
    final s = c.read(fleetControllerProvider);
    expect(s.isRunning, isFalse);
    expect(s.activeBikeId, isNull);
    expect(s.summary, startsWith('Interrompida.'));
    expect(_status(c, 'A'), FleetBikeStatus.disconnected);
    expect(_bike(c, 'A').message, 'Interrompida.');

    await run.timeout(const Duration(milliseconds: 200));
    expect(gw.calls, contains('disconnect A'));
    expect(gw.calls, isNot(contains('connect B')));
  });

  test('parar durante a conexão não espera o tempo limite', () async {
    final (c, gw) = await _setup(
      settings: const AppSettings(
        retries: 0,
        scanSeconds: 1,
        timeoutSeconds: 30,
      ),
    );
    gw.connectGate = Completer<void>(); // conexão travada
    final ctrl = c.read(fleetControllerProvider.notifier);
    final run = ctrl.start();
    await _until(c, (s) => s.activeStep == FleetStep.connecting);

    final sw = Stopwatch()..start();
    ctrl.stop();
    await run;
    expect(sw.elapsed, lessThan(const Duration(milliseconds: 200)));
    expect(gw.calls, contains('disconnect A'));
  });

  test('iniciar de novo zera a lista e começa do zero', () async {
    final (c, gw) = await _setup();
    gw.gearGate = Completer<void>();
    final ctrl = c.read(fleetControllerProvider.notifier);
    unawaited(ctrl.start());
    await _until(c, (s) => s.activeStep == FleetStep.settingGear);
    ctrl.stop();

    gw
      ..gearGate = null
      ..calls.clear();
    final again = ctrl.start();
    final s = c.read(fleetControllerProvider);
    expect(s.isRunning, isTrue);
    expect(s.bikes, isEmpty);
    expect(s.summary, isNull);

    await again;
    expect(gw.calls.first, 'connect A');
    for (final id in ['A', 'B', 'C']) {
      expect(_status(c, id), FleetBikeStatus.completed);
    }
  });

  group('som ao concluir', () {
    test('toca o som escolhido a cada bike concluída', () async {
      final (c, gw) = await _setup(
        settings: const AppSettings(
          retries: 0,
          scanSeconds: 1,
          successSound: 'marimba',
        ),
      );
      gw.failAt['B'] = 'auth';
      await c.read(fleetControllerProvider.notifier).start();

      final sound = c.read(successSoundProvider) as FakeSuccessSound;
      // A e C concluem (B falha) -> dois toques, com a chave configurada.
      expect(sound.played, ['marimba', 'marimba']);
    });

    test('desligado não toca', () async {
      final (c, _) = await _setup(
        settings: const AppSettings(
          retries: 0,
          scanSeconds: 1,
          soundOnSuccess: false,
        ),
      );
      await c.read(fleetControllerProvider.notifier).start();
      final sound = c.read(successSoundProvider) as FakeSuccessSound;
      expect(sound.played, isEmpty);
    });
  });

  group('lista de bloqueio', () {
    test('bike bloqueada aparece na lista mas é pulada', () async {
      final (c, gw) = await _setup(blocked: {'B': 'Bike B'});
      await c.read(fleetControllerProvider.notifier).start();

      expect(c.read(fleetControllerProvider).bikes.map((b) => b.id), [
        'A',
        'B',
        'C',
      ]);
      expect(gw.calls.where((x) => x.contains(' B')), isEmpty);
      expect(_status(c, 'A'), FleetBikeStatus.completed);
      expect(_status(c, 'C'), FleetBikeStatus.completed);
      final s = c.read(fleetControllerProvider);
      expect(s.total, 2);
      expect(s.summary, contains('1 bloqueada(s) pulada(s)'));
    });

    test('bloquear durante a operação pula quando chegar a vez', () async {
      final (c, gw) = await _setup();
      gw.gearGate = Completer<void>();
      final run = c.read(fleetControllerProvider.notifier).start();
      await _until(c, (s) => s.activeStep == FleetStep.settingGear);

      await c.read(fleetBlocklistProvider.notifier).block('B', 'Bike B');
      gw.gearGate!.complete();
      await run;
      expect(gw.calls, isNot(contains('connect B')));
      expect(gw.calls, contains('connect C'));
    });

    test('incluir e remover persiste', () async {
      final (c, _) = await _setup();
      final bl = c.read(fleetBlocklistProvider.notifier);
      await bl.block('A', 'Bike A');
      expect(c.read(fleetBlocklistProvider), {'A': 'Bike A'});
      final saved = c.read(fleetBlocklistLocalProvider).load();
      expect(saved, {'A': 'Bike A'});

      await bl.toggle('A', 'Bike A');
      expect(c.read(fleetBlocklistProvider), isEmpty);
      expect(c.read(fleetBlocklistLocalProvider).load(), isEmpty);
    });

    test('operação contínua também pula bloqueadas', () async {
      final (c, gw) = await _setup(blocked: {'A': 'Bike A'});
      final ctrl = c.read(fleetControllerProvider.notifier);
      final run = ctrl.startContinuous();
      await _until(c, (s) => s.cycle >= 2);
      ctrl.stop();
      await run;
      expect(gw.calls, isNot(contains('connect A')));
      expect(gw.calls, contains('connect B'));
    });
  });

  test('parar durante a busca encerra sem processar', () async {
    final (c, gw) = await _setup(bikes: const []);
    final ctrl = c.read(fleetControllerProvider.notifier);
    final run = ctrl.start();
    await pumpEventQueue();
    ctrl.stop();
    await run;
    final s = c.read(fleetControllerProvider);
    expect(s.isRunning, isFalse);
    expect(s.isRefreshing, isFalse);
    expect(s.summary, startsWith('Interrompida.'));
    expect(gw.calls, isEmpty);
  });

  group('operação contínua', () {
    test('repete ciclos, não repete concluídas e tenta de novo as que '
        'falharam', () async {
      final (c, gw) = await _setup();
      gw.failAt['B'] = 'connect';
      final ctrl = c.read(fleetControllerProvider.notifier);

      final run = ctrl.startContinuous();
      await _until(c, (s) => s.cycle >= 3);
      expect(c.read(fleetControllerProvider).isContinuous, isTrue);
      expect(gw.calls.where((x) => x == 'connect A'), hasLength(1));
      expect(
        gw.calls.where((x) => x == 'connect B').length,
        greaterThanOrEqualTo(2),
      );

      // Uma bike nova chega: entra no fim da lista e é acionada.
      gw.bikes = [..._bikes, const FleetBike(id: 'D', name: 'Bike D')];
      await _until(
        c,
        (s) => s.bikes.any(
          (b) => b.id == 'D' && b.status == FleetBikeStatus.completed,
        ),
      );
      expect(c.read(fleetControllerProvider).bikes.last.id, 'D');

      ctrl.stop();
      await run;
      final s = c.read(fleetControllerProvider);
      expect(s.isRunning, isFalse);
      expect(s.summary, startsWith('Operação contínua parada após'));
      expect(s.summary, contains('3 concluída(s)'));
    });

    test('histórico por ciclo: só ciclos com bikes, retentativa aparece de '
        'novo e bloqueada só na primeira vez', () async {
      final (c, gw) = await _setup(blocked: {'C': 'Bike C'});
      gw.failAt['B'] = 'connect';
      final ctrl = c.read(fleetControllerProvider.notifier);
      final run = ctrl.startContinuous();
      await _until(c, (s) => s.cycle >= 4);
      gw.failAt.remove('B');
      await _until(
        c,
        (s) => s.bikes.any(
          (b) => b.id == 'B' && b.status == FleetBikeStatus.completed,
        ),
      );
      await _until(c, (s) => s.cycle >= s.cycleLog.last.number + 2);
      ctrl.stop();
      await run;

      final all = c.read(fleetControllerProvider).cycleLog;
      final log = all.where((l) => !l.isEmpty).toList();
      // Ciclo 1: A (ok), B (falha), C (bloqueada, vista pela 1ª vez).
      expect(log.first.number, 1);
      expect(log.first.bikes.map((b) => b.id), ['A', 'B', 'C']);
      expect(log.first.bikes[0].status, FleetBikeStatus.completed);
      expect(log.first.bikes[1].status, FleetBikeStatus.failed);
      // Ciclos seguintes: só a B (retentativas); A e C não se repetem.
      for (final l in log.skip(1)) {
        expect(l.bikes.map((b) => b.id), ['B']);
      }
      expect(log.last.bikes.single.status, FleetBikeStatus.completed);
      // Depois que a B concluiu, os ciclos vazios viram um registro só.
      final tail = all.last;
      expect(tail.isEmpty, isTrue);
      expect(tail.number, log.last.number + 1);
      // O ciclo atual (que ainda buscava ao parar) pode não ter entrado.
      expect(
        tail.lastNumber,
        greaterThanOrEqualTo(c.read(fleetControllerProvider).cycle - 1),
      );
      expect(tail.isRange, isTrue);
      // Nunca dois registros vazios seguidos.
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].isEmpty && all[i].isEmpty, isFalse);
      }
      // O histórico de um ciclo anterior não muda depois.
      expect(log[1].bikes.single.status, FleetBikeStatus.failed);
    });

    test('parar durante a busca do ciclo encerra', () async {
      final (c, gw) = await _setup(bikes: const []);
      final ctrl = c.read(fleetControllerProvider.notifier);
      final run = ctrl.startContinuous();
      await _until(c, (s) => s.isRefreshing && s.cycle == 1);
      ctrl.stop();
      await run;
      expect(c.read(fleetControllerProvider).isRunning, isFalse);
      expect(gw.calls, isEmpty);
    });
  });

  test('modo simulação troca a fonte das bicicletas', () async {
    final settings = MemorySettings(const AppSettings());
    final c = ProviderContainer(
      overrides: [appSettingsLocalProvider.overrideWithValue(settings)],
    );
    addTearDown(c.dispose);
    expect(c.read(bikeFleetGatewayProvider), isA<BleBikeFleetGateway>());

    await c
        .read(appSettingsProvider.notifier)
        .update(const AppSettings(useMock: true));
    expect(c.read(bikeFleetGatewayProvider), isA<MockBikeFleetGateway>());
  });

  group('AppSettings', () {
    test('valores inválidos voltam ao padrão', () {
      final s = AppSettings.fromMap({
        'defaultPassword': '12',
        'targetGear': 9,
        'timeoutSeconds': 20,
        'retries': 'x',
        'scanSeconds': 2,
        'lockBikes': 'sim',
        'useMock': 1,
        'keepScreenOn': true,
        'soundOnSuccess': 'nao',
        'successSound': 'inexistente',
      });
      expect(s.defaultPassword, AppConstants.defaultPassword);
      expect(s.targetGear, 0);
      expect(s.timeoutSeconds, 20);
      expect(s.retries, 1);
      expect(s.scanSeconds, 10);
      expect(s.lockBikes, isTrue);
      expect(s.useMock, isFalse);
      expect(s.keepScreenOn, isTrue);
      expect(s.soundOnSuccess, isTrue);
      expect(s.successSound, 'sino');
      expect(
        AppSettings.fromMap({'successSound': 'game'}).successSound,
        'game',
      );
      expect(AppSettings.fromMap({'lockBikes': false}).lockBikes, isFalse);
    });

    test('persiste no Hive e restaura padrões', () async {
      final dir = await Directory.systemTemp.createTemp('settings_test');
      Hive.init(dir.path);
      await Hive.openBox<dynamic>(AppConstants.appSettingsBox);
      addTearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });

      final c1 = ProviderContainer();
      await c1
          .read(appSettingsProvider.notifier)
          .update(const AppSettings(defaultPassword: '654321', targetGear: 2));
      c1.dispose();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      expect(c2.read(appSettingsProvider).defaultPassword, '654321');
      expect(c2.read(appSettingsProvider).targetGear, 2);

      await c2.read(appSettingsProvider.notifier).resetToDefaults();
      expect(c2.read(appSettingsProvider).targetGear, 0);
      expect(Hive.box<dynamic>(AppConstants.appSettingsBox).isEmpty, isTrue);
    });
  });
}
