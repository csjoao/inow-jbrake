import 'dart:async';
import 'dart:math';

import '../../domain/entities/fleet_bike.dart';
import '../../domain/gateways/bike_fleet_gateway.dart';

/// Bicicletas simuladas, sem Bluetooth. Usado nos testes e para desenvolver
/// a tela sem bikes por perto.
class MockBikeFleetGateway implements BikeFleetGateway {
  MockBikeFleetGateway({
    Random? random,
    this.stepDelay = const Duration(milliseconds: 700),
    this.failureRate = 0.15,
    List<FleetBike>? fleet,
    this.growFleet = true,
  }) : _random = random ?? Random(),
       _fleet = [...(fleet ?? _defaultFleet)];

  final Random _random;
  final Duration stepDelay;

  /// Chance de falha em cada etapa (0 a 1).
  final double failureRate;
  final List<FleetBike> _fleet;

  /// A cada busca, às vezes "chega" uma bike nova (até 12), para ver a lista
  /// crescer na operação contínua.
  final bool growFleet;
  StreamController<List<FleetBike>>? _scan;

  static const _defaultFleet = [
    FleetBike(id: 'C4:7F:51:0A:12:01', name: 'INOW-0101', rssi: -52),
    FleetBike(id: 'C4:7F:51:0A:12:02', name: 'INOW-0102', rssi: -61),
    FleetBike(id: 'C4:7F:51:0A:12:03', name: 'INOW-0103', rssi: -70),
    FleetBike(id: 'C4:7F:51:0A:12:04', name: 'INOW-0104', rssi: -78),
  ];

  /// Emite uma bike nova a cada [stepDelay] e fica aberto até parar.
  @override
  Stream<List<FleetBike>> discover() {
    unawaited(_scan?.close());
    if (growFleet && _fleet.length < 12 && _random.nextBool()) {
      final n = (_fleet.length + 1).toString().padLeft(2, '0');
      _fleet.add(
        FleetBike(
          id: 'C4:7F:51:0A:12:$n',
          name: 'INOW-01$n',
          rssi: -50 - _random.nextInt(40),
        ),
      );
    }
    final ctrl = StreamController<List<FleetBike>>();
    _scan = ctrl;
    () async {
      final found = <FleetBike>[];
      for (final b in _fleet) {
        await Future<void>.delayed(stepDelay);
        if (ctrl.isClosed) return;
        found.add(b);
        ctrl.add([...found]);
      }
    }();
    return ctrl.stream;
  }

  @override
  Future<void> stopDiscovery() async {
    await _scan?.close();
    _scan = null;
  }

  @override
  Future<void> connect(String bikeId) =>
      _step('A bicicleta não respondeu à conexão.');

  @override
  Future<void> authenticate(String bikeId, String password) =>
      _step('Senha recusada (CODE_NG).');

  @override
  Future<FleetBikeDetails> identify(String bikeId) async {
    await Future<void>.delayed(stepDelay);
    // Uma em cada três bikes não tem trava (para ver o "sem trava").
    final n = int.tryParse(bikeId.split(':').last) ?? 0;
    return FleetBikeDetails(
      model: n.isEven ? 'imoogoo-inow05' : 'imoogoo-inow07',
      features: [
        BikeFeature.gear,
        if (n % 3 != 0) BikeFeature.lock,
        BikeFeature.headlight,
      ],
    );
  }

  @override
  Future<void> setGear(String bikeId, int level) =>
      _step('A bike não confirmou a marcha (+MODE=?).');

  @override
  Future<void> lock(String bikeId) =>
      _step('A bike não confirmou a trava (+LOCK=?).');

  @override
  Future<void> disconnect(String bikeId) =>
      Future<void>.delayed(stepDelay ~/ 2);

  Future<void> _step(String failureMessage) async {
    await Future<void>.delayed(stepDelay);
    if (_random.nextDouble() < failureRate) {
      throw FleetFailure(failureMessage);
    }
  }
}
