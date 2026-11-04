import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../protocol/inow_ble_profile.dart';

class ScannedBike {
  const ScannedBike({
    required this.device,
    required this.name,
    required this.rssi,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;

  String get id => device.remoteId.str;
}

/// Conexão aberta com uma bike: canal de escrita + notificações.
class BikeLink {
  BikeLink._(this.device, this.profile, this._write, this._notify);

  final BluetoothDevice device;
  final InowBleProfile profile;
  final BluetoothCharacteristic _write;
  final BluetoothCharacteristic _notify;

  Future<void> _queue = Future.value();

  Stream<List<int>> get incoming => _notify.onValueReceived;

  Stream<bool> get disconnected => device.connectionState
      .where((s) => s == BluetoothConnectionState.disconnected)
      .map((_) => true);

  /// Escritas em fila (o Bluetooth não aceita duas ao mesmo tempo).
  Future<void> send(List<int> data) {
    final withoutResponse =
        !_write.properties.write && _write.properties.writeWithoutResponse;
    final next = _queue.then(
      (_) => _write.write(data, withoutResponse: withoutResponse),
    );
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> close() => device.disconnect();
}

/// Acesso ao Bluetooth (flutter_blue_plus) no formato que a bike espera.
class BikeBleDataSource {
  static final _serviceGuids = [
    for (final p in InowBleProfile.values) Guid(p.service),
  ];

  Future<void> ensurePermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    }
    // No iOS o próprio CoreBluetooth mostra o pedido na primeira vez.
  }

  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// Procura bikes INOW por perto (filtra pelo serviço anunciado).
  Stream<List<ScannedBike>> scan({
    Duration timeout = const Duration(seconds: 15),
  }) {
    unawaited(_startScan(timeout));
    return FlutterBluePlus.scanResults.map(
      (results) => [
        for (final r in results)
          ScannedBike(
            device: r.device,
            name: r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : (r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : r.device.remoteId.str),
            rssi: r.rssi,
          ),
      ]..sort((a, b) => b.rssi.compareTo(a.rssi)),
    );
  }

  Future<void> _startScan(Duration timeout) async {
    await ensurePermissions();
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 5));
    await FlutterBluePlus.startScan(
      withServices: _serviceGuids,
      timeout: timeout,
    );
  }

  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  /// Conecta, acha o serviço INOW e liga as notificações.
  Future<BikeLink> connect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    await device.connect(license: License.nonprofit);
    final services = await device.discoverServices();

    for (final s in services) {
      final profile = InowBleProfile.forService(s.uuid.str128);
      if (profile == null) continue;
      BluetoothCharacteristic? write;
      BluetoothCharacteristic? notify;
      for (final c in s.characteristics) {
        final u = c.uuid.str128.toLowerCase();
        if (u == profile.write) write = c;
        if (u == profile.notify) notify = c;
      }
      if (write != null && notify != null) {
        await notify.setNotifyValue(true);
        return BikeLink._(device, profile, write, notify);
      }
    }

    await device.disconnect();
    throw StateError('Serviço INOW não encontrado nesse aparelho.');
  }
}
