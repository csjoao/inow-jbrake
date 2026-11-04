import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/bike_ble_datasource.dart';
import '../../data/datasources/bike_local_datasource.dart';
import '../../data/protocol/auth_handshake.dart';
import '../../data/protocol/inow_commands.dart';
import '../../data/protocol/inow_text.dart';
import '../../data/protocol/telemetry_parser.dart';
import '../../domain/entities/bike_state.dart';

final bikeBleProvider = Provider((ref) => BikeBleDataSource());
final bikeLocalProvider = Provider((ref) => BikeLocalDataSource());

/// Lista de bikes encontradas no scan (reinicia o scan ao ser observado).
final scanResultsProvider = StreamProvider.autoDispose<List<ScannedBike>>((
  ref,
) {
  final ble = ref.watch(bikeBleProvider);
  ref.onDispose(ble.stopScan);
  return ble.scan();
});

final isScanningProvider = StreamProvider.autoDispose<bool>(
  (ref) => ref.watch(bikeBleProvider).isScanning,
);

/// Tudo que passou pelo Bluetooth (tela Console).
final bikeLogProvider = NotifierProvider<BikeLog, List<LogLine>>(BikeLog.new);

class BikeLog extends Notifier<List<LogLine>> {
  @override
  List<LogLine> build() => const [];

  void add(LogLine line) {
    final next = [...state, line];
    state = next.length > 500 ? next.sublist(next.length - 500) : next;
  }

  void clear() => state = const [];
}

final bikeControllerProvider = NotifierProvider<BikeController, BikeState>(
  BikeController.new,
);

class BikeController extends Notifier<BikeState> {
  BikeLink? _link;
  AuthHandshake? _auth;
  String? _pendingPassword;
  final _subs = <StreamSubscription<Object?>>[];
  Completer<void>? _trusted;
  Completer<bool>? _codeResult;

  BikeLocalDataSource get _local => ref.read(bikeLocalProvider);

  @override
  BikeState build() {
    ref.onDispose(_teardown);
    final last = _local.lastBike;
    return BikeState(deviceId: last?.id, name: last?.name);
  }

  String? savedPasswordFor(String deviceId) => _local.passwordFor(deviceId);

  /// Conecta, autentica e envia a senha. Retorna `null` se deu certo ou a
  /// mensagem de erro.
  Future<String?> connect(ScannedBike bike, String password) async {
    await _teardown();
    state = BikeState(
      phase: BikePhase.connecting,
      deviceId: bike.id,
      name: bike.name,
    );

    try {
      final link = await ref.read(bikeBleProvider).connect(bike.device);
      _link = link;
      _auth = AuthHandshake(link.profile);
      _trusted = Completer<void>();
      _codeResult = Completer<bool>();
      _pendingPassword = password;

      _subs
        ..add(link.incoming.listen(_onBytes))
        ..add(link.disconnected.listen((_) => _onDisconnected()));

      state = state.copyWith(phase: BikePhase.authenticating);

      // Mesma sequência/tempos do app oficial: autenticação mútua e,
      // em seguida (no máximo 2,5 s depois), a senha.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _send(_auth!.start());
      await _trusted!.future.timeout(
        const Duration(milliseconds: 2500),
        onTimeout: () {},
      );
      await _send(InowCommands.password(password));

      final ok = await _codeResult!.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );
      if (!ok) {
        final msg = _codeResult!.isCompleted
            ? 'Senha incorreta.'
            : 'A bike não respondeu à senha.';
        await disconnect();
        state = state.copyWith(error: msg);
        return msg;
      }
      return null;
    } catch (e) {
      await _teardown();
      final msg = 'Falha ao conectar: $e';
      state = state.copyWith(phase: BikePhase.disconnected, error: msg);
      return msg;
    }
  }

  Future<void> _afterCodeOk() async {
    final id = state.deviceId!;
    await _local.savePassword(id, _pendingPassword!);
    await _local.saveLastBike(id, state.name ?? id);
    state = state.copyWith(phase: BikePhase.connected, clearError: true);

    // Consultas iniciais, espaçadas como no app oficial.
    for (final cmd in [
      InowCommands.deviceId,
      InowCommands.maxModeQuery,
      InowCommands.modeQuery,
      InowCommands.lockQuery,
      InowCommands.headlightQuery,
      InowCommands.unitQuery,
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_link == null) return;
      await _send(cmd);
    }
  }

  void _onBytes(List<int> bytes) {
    // Binário primeiro: alguns pacotes (":" ... CR LF) podem parecer texto.
    final t = parseTelemetry(bytes);
    final text = t == null ? asInowText(bytes) : null;
    ref.read(bikeLogProvider.notifier).add(LogLine(false, text ?? _hex(bytes)));

    if (text != null) {
      _onText(text.trim());
      return;
    }
    if (t == null) return;

    state = state.copyWith(
      telemetryFormats: {...state.telemetryFormats, t.format},
      battery: t.battery,
      speed: t.speed,
      trip: t.trip,
      odo: t.odo,
      info: state.info.merge(
        voltage: t.voltage,
        current: t.current,
        chargeCycles: t.chargeCycles,
        software: t.software,
        firmware: t.firmware,
        rideDistance: t.rideDistance,
        rideTopSpeed: t.rideTopSpeed,
        rideSeconds: t.rideSeconds,
        totalDistance: t.totalDistance,
        totalSeconds: t.totalSeconds,
      ),
    );
  }

  void _onText(String raw) {
    final msg = raw.toUpperCase();

    // Autenticação mútua.
    final auth = _auth;
    if (auth != null && !(auth.trusted && auth.credible)) {
      final reply = auth.onMessage(msg);
      if (reply != null) unawaited(_send(reply));
      if (auth.trusted && !(_trusted?.isCompleted ?? true)) {
        _trusted!.complete();
      }
    }

    if (msg == 'CODE_OK') {
      if (!(_codeResult?.isCompleted ?? true)) {
        _codeResult!.complete(true);
        unawaited(_afterCodeOk());
      }
      return;
    }
    if (msg == 'CODE_NG') {
      if (state.deviceId != null) {
        unawaited(_local.removePassword(state.deviceId!));
      }
      if (!(_codeResult?.isCompleted ?? true)) _codeResult!.complete(false);
      return;
    }
    if (msg.contains('IMOOGOO')) {
      state = state.copyWith(model: raw);
      return;
    }

    // Respostas no formato [+]CHAVE=valor.
    final m = RegExp(r'^\+?([A-Z]+)=(.+)$').firstMatch(msg);
    if (m == null) return;
    final key = m.group(1)!;
    final value = m.group(2)!;
    state = state.copyWith(values: {...state.values, key: value});

    switch (key) {
      case 'MODE':
        final n = int.tryParse(value);
        if (n != null) state = state.copyWith(mode: n);
      case 'MDMX':
        final n = int.tryParse(value);
        if (n != null) state = state.copyWith(maxMode: n);
      case 'LOCK':
        if (value == '0' || value == '1') {
          state = state.copyWith(locked: value == '1');
        }
      case 'HLGT':
        if (value == '0' || value == '1') {
          state = state.copyWith(headlight: value == '1');
        }
      case 'RFRP':
        // +RFRP=IIPPPPPPPP — II = id do cartão, P = zeros quando vazio.
        if (value.length >= 10 && value.substring(2, 10) != '00000000') {
          final id = value.substring(0, 2);
          if (!state.nfcCards.contains(id)) {
            state = state.copyWith(nfcCards: [...state.nfcCards, id]);
          }
        }
      case 'RFAD':
        if (value == 'E5') {
          state = state.copyWith(nfcPairing: NfcPairing.alreadyBound);
          unawaited(_send(InowCommands.nfcStopPairing));
        } else if (value == 'E4') {
          state = state.copyWith(nfcPairing: NfcPairing.failed);
          unawaited(_send(InowCommands.nfcStopPairing));
        } else if (value.length > 2) {
          final id = value.substring(0, 2);
          state = state.copyWith(
            nfcPairing: NfcPairing.success,
            nfcCards: state.nfcCards.contains(id)
                ? state.nfcCards
                : [...state.nfcCards, id],
          );
          unawaited(_send(InowCommands.nfcStopPairing));
        }
    }
  }

  Future<void> setMode(int level) async {
    if (level < 1 || level > state.maxMode) return;
    state = state.copyWith(mode: level);
    await _send(InowCommands.mode(level));
  }

  Future<void> setLocked(bool locked) async {
    state = state.copyWith(locked: locked);
    await _send(InowCommands.lock(locked: locked));
  }

  Future<void> setHeadlight(bool on) async {
    state = state.copyWith(headlight: on);
    await _send(InowCommands.headlight(on: on));
  }

  /// Envia um comando e, 200 ms depois, a consulta (para a tela refletir
  /// o valor que a bike realmente aceitou).
  Future<void> setAndQuery(String command, String query) async {
    await _send(command);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _send(query);
  }

  /// Envia várias consultas espaçadas (a bike perde comandos colados).
  Future<void> queryAll(Iterable<String> queries) async {
    for (final q in queries) {
      await _send(q);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Troca a senha de conexão Bluetooth e já guarda a nova no celular.
  Future<void> changeBlePassword(String pwd) async {
    await _send(InowCommands.blePassword(pwd));
    final id = state.deviceId;
    if (id != null) await _local.savePassword(id, pwd);
  }

  Future<void> renameBike(String name) async {
    await _send(InowCommands.bleName(name));
    final id = state.deviceId;
    if (id != null) await _local.saveLastBike(id, name);
    state = state.copyWith(name: name);
  }

  Future<void> refreshNfcCards() async {
    state = state.copyWith(nfcCards: const []);
    await _send(InowCommands.nfcList);
  }

  Future<void> startNfcPairing() async {
    state = state.copyWith(nfcPairing: NfcPairing.waitingCard);
    await _send(InowCommands.nfcStopPairing);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _send(InowCommands.nfcStartPairing);
  }

  Future<void> stopNfcPairing() async {
    state = state.copyWith(nfcPairing: NfcPairing.idle);
    await _send(InowCommands.nfcStopPairing);
  }

  Future<void> deleteNfcCard(String id) async {
    await _send(InowCommands.nfcDelete(id));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await refreshNfcCards();
  }

  /// Envia qualquer texto (tela Console / ajustes).
  Future<void> sendRaw(String text) => _send(text);

  Future<void> disconnect() async {
    await _teardown();
    state = state.copyWith(phase: BikePhase.disconnected, speed: 0);
  }

  Future<void> forgetBike() async {
    await disconnect();
    await _local.forgetLastBike();
    state = const BikeState();
  }

  Future<void> _send(String text) async {
    final link = _link;
    if (link == null) return;
    ref.read(bikeLogProvider.notifier).add(LogLine(true, text));
    await link.send(utf8.encode(text));
  }

  void _onDisconnected() {
    if (_link == null) return;
    _link = null;
    state = state.copyWith(
      phase: BikePhase.disconnected,
      speed: 0,
      error: 'A bike desconectou.',
    );
  }

  Future<void> _teardown() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final link = _link;
    _link = null;
    _auth = null;
    if (link != null) {
      try {
        await link.close();
      } catch (_) {}
    }
  }

  static String _hex(List<int> b) => b
      .map((x) => (x & 0xFF).toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();
}
