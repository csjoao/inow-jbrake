import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../bike/data/datasources/bike_ble_datasource.dart';
import '../../../bike/data/protocol/auth_handshake.dart';
import '../../../bike/data/protocol/inow_commands.dart';
import '../../../bike/data/protocol/inow_text.dart';
import '../../../bike/data/protocol/telemetry_parser.dart';
import '../../../bike/domain/entities/bike_state.dart';
import '../../domain/entities/fleet_bike.dart';
import '../../domain/gateways/bike_fleet_gateway.dart';

/// Operação em lote pelo Bluetooth real. Mesma sequência e tempos do
/// `BikeController` (aba Veículo), mas uma bike de cada vez e sem telemetria.
class BleBikeFleetGateway implements BikeFleetGateway {
  BleBikeFleetGateway(this._ble, {this.log});

  final BikeBleDataSource _ble;

  /// Tráfego enviado/recebido (aparece na tela Console).
  final void Function(LogLine line)? log;

  /// Aparelhos vistos na busca (precisa do `BluetoothDevice` para conectar).
  final _found = <String, ScannedBike>{};
  _Session? _session;

  /// Muda a cada [disconnect]; descarta conexões que terminam atrasadas.
  int _generation = 0;

  @override
  Stream<List<FleetBike>> discover() async* {
    _found.clear();
    await _ble.ensurePermissions();
    try {
      await _ble.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          // Inclui o tempo de responder ao pedido de permissão no iOS.
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const FleetFailure('Bluetooth desligado ou sem permissão.');
    }
    // O tempo limite real fica no controlador; este é só uma garantia.
    yield* _ble.scan(timeout: const Duration(seconds: 60)).map((list) {
      for (final b in list) {
        _found[b.id] = b;
      }
      return [
        for (final b in list) FleetBike(id: b.id, name: b.name, rssi: b.rssi),
      ];
    });
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      await _ble.stopScan();
    } catch (_) {}
  }

  @override
  Future<void> connect(String bikeId) async {
    final bike = _found[bikeId];
    if (bike == null) {
      throw const FleetFailure('Bicicleta fora da última busca.');
    }
    await _closeSession();
    final gen = _generation;
    final BikeLink link;
    try {
      link = await _ble.connect(bike.device);
    } on StateError catch (e) {
      throw FleetFailure(e.message);
    } catch (e) {
      throw FleetFailure('Falha ao conectar: $e');
    }
    if (gen != _generation) {
      // Tempo esgotado ou "Parar" enquanto conectava.
      await _safeClose(link);
      throw const FleetFailure('Conexão cancelada.');
    }
    _session = _Session(link, log);
  }

  @override
  Future<void> authenticate(String bikeId, String password) async {
    final s = _require(bikeId);
    final auth = AuthHandshake(s.link.profile);
    s.auth = auth;

    // Como no app oficial: 500 ms após ligar as notificações, `+VER?`;
    // segue com a senha assim que a bike confiar (ou após 2,5 s).
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final trusted = s.waitFor(
      (_) => auth.trusted,
      const Duration(milliseconds: 2500),
    );
    await s.send(auth.start());
    try {
      await trusted;
    } on TimeoutException {
      // O original também segue sem `+PM=OK`.
    }
    if (auth.rejected) {
      throw const FleetFailure('A bike recusou a autenticação (+PM=NK).');
    }

    final reply = s.waitFor(
      (m) => m == 'CODE_OK' || m == 'CODE_NG',
      const Duration(seconds: 6),
    );
    await s.send(InowCommands.password(password));
    final String answer;
    try {
      answer = await reply;
    } on TimeoutException {
      throw const FleetFailure('A bike não respondeu à senha.');
    }
    if (answer == 'CODE_NG') {
      throw const FleetFailure('Senha recusada (CODE_NG).');
    }
  }

  @override
  Future<FleetBikeDetails> identify(String bikeId) async {
    final s = _require(bikeId);
    String? model;
    final features = <BikeFeature>{};

    final sub = s.lines.listen((m) {
      if (m.contains('IMOOGOO')) model = s.lastRaw;
      if (_key(m) case final k?) {
        switch (k) {
          case 'MDMX' || 'MODE':
            features.add(BikeFeature.gear);
          case 'LOCK':
            features.add(BikeFeature.lock);
          case 'HLGT':
            features.add(BikeFeature.headlight);
        }
      }
    }, onError: (Object _) {});
    try {
      for (final q in [
        InowCommands.deviceId,
        InowCommands.maxModeQuery,
        InowCommands.lockQuery,
        InowCommands.headlightQuery,
      ]) {
        await s.send(q);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      // Tempo para as últimas respostas chegarem.
      await Future<void>.delayed(const Duration(milliseconds: 600));
    } finally {
      await sub.cancel();
    }
    return FleetBikeDetails(
      model: model,
      features: [
        for (final f in BikeFeature.values)
          if (features.contains(f)) f,
      ],
    );
  }

  @override
  Future<void> setGear(String bikeId, int level) async {
    final got = await _setAndRead(
      _require(bikeId),
      InowCommands.mode(level),
      InowCommands.modeQuery,
      'MODE',
      onNoReply: 'A bike não confirmou a marcha (+MODE=?).',
    );
    if (int.tryParse(got) != level) {
      throw FleetFailure('A bike ficou na marcha $got (pedido: $level).');
    }
  }

  @override
  Future<void> lock(String bikeId) async {
    final got = await _setAndRead(
      _require(bikeId),
      InowCommands.lock(locked: true),
      InowCommands.lockQuery,
      'LOCK',
      onNoReply: 'A bike não confirmou a trava (+LOCK=?).',
    );
    if (got != '1') {
      throw FleetFailure('A bike não travou (+LOCK=$got).');
    }
  }

  /// Envia o comando, consulta 200 ms depois e devolve o valor de `CHAVE=`.
  Future<String> _setAndRead(
    _Session s,
    String command,
    String query,
    String key, {
    required String onNoReply,
  }) async {
    await s.send(command);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final reply = s.waitFor((m) => _key(m) == key, const Duration(seconds: 3));
    await s.send(query);
    try {
      return (await reply).split('=').last;
    } on TimeoutException {
      throw FleetFailure(onNoReply);
    }
  }

  @override
  Future<void> disconnect(String bikeId) async {
    _generation++;
    if (_session != null) {
      await _closeSession();
      return;
    }
    // Cancela uma conexão que ainda estava sendo feita.
    try {
      await _found[bikeId]?.device.disconnect();
    } catch (_) {}
  }

  _Session _require(String bikeId) {
    final s = _session;
    if (s == null || s.link.device.remoteId.str != bikeId) {
      throw const FleetFailure('Bicicleta não está conectada.');
    }
    if (s.dropped) throw const FleetFailure('A bike desconectou.');
    return s;
  }

  Future<void> _closeSession() async {
    final s = _session;
    _session = null;
    if (s != null) await s.close();
  }

  static Future<void> _safeClose(BikeLink link) async {
    try {
      await link.close();
    } catch (_) {}
  }

  /// `+MODE=1` / `MODE=1` → `MODE`.
  static String? _key(String msg) =>
      RegExp(r'^\+?([A-Z]+)=').firstMatch(msg)?.group(1);
}

/// Uma conexão aberta: transforma as notificações em linhas de texto e
/// responde sozinha à autenticação mútua.
class _Session {
  _Session(this.link, this._log) {
    _subs
      ..add(link.incoming.listen(_onBytes))
      ..add(
        link.disconnected.listen((_) {
          dropped = true;
          _lines.addError(const FleetFailure('A bike desconectou.'));
        }),
      );
  }

  final BikeLink link;
  final void Function(LogLine)? _log;
  final _subs = <StreamSubscription<Object?>>[];
  final _lines = StreamController<String>.broadcast();
  AuthHandshake? auth;
  bool dropped = false;

  /// Última mensagem como chegou (o modelo é guardado sem maiúsculas).
  String? lastRaw;

  /// Mensagens de texto já em maiúsculas e sem espaços nas pontas.
  Stream<String> get lines => _lines.stream;

  /// Comece a esperar ANTES de enviar o comando, para não perder a resposta.
  /// Se o envio falhar antes de alguém aguardar, o erro não fica solto.
  Future<String> waitFor(bool Function(String) test, Duration timeout) {
    final f = _lines.stream.firstWhere(test).timeout(timeout);
    f.ignore();
    return f;
  }

  Future<void> send(String text) async {
    if (dropped) throw const FleetFailure('A bike desconectou.');
    _log?.call(LogLine(true, text));
    await link.send(utf8.encode(text));
  }

  void _onBytes(List<int> bytes) {
    // Telemetria binária é ignorada aqui (mesma checagem do BikeController).
    if (parseTelemetry(bytes) != null) return;
    final text = asInowText(bytes);
    if (text == null) return;
    _log?.call(LogLine(false, text));
    final raw = text.trim();
    final msg = raw.toUpperCase();
    lastRaw = raw;

    final a = auth;
    if (a != null && !(a.trusted && a.credible)) {
      final reply = a.onMessage(msg);
      if (reply != null) unawaited(send(reply).catchError((Object _) {}));
    }
    if (!_lines.isClosed) _lines.add(msg);
  }

  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _lines.close();
    try {
      await link.close();
    } catch (_) {}
  }
}
