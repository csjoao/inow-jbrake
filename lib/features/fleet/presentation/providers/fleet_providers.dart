import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_settings/domain/entities/app_settings.dart';
import '../../../app_settings/presentation/providers/app_settings_providers.dart';
import '../../../bike/domain/entities/bike_state.dart';
import '../../../../core/services/success_sound.dart';
import '../../../bike/presentation/providers/bike_providers.dart';
import '../../data/gateways/ble_bike_fleet_gateway.dart';
import '../../data/gateways/mock_bike_fleet_gateway.dart';
import '../../domain/entities/fleet_bike.dart';
import '../../domain/gateways/bike_fleet_gateway.dart';
import 'fleet_blocklist_providers.dart';

/// Bluetooth real, ou bikes simuladas se "Modo simulação" estiver ligado.
final bikeFleetGatewayProvider = Provider<BikeFleetGateway>((ref) {
  if (ref.watch(appSettingsProvider.select((s) => s.useMock))) {
    return MockBikeFleetGateway();
  }
  return BleBikeFleetGateway(
    ref.watch(bikeBleProvider),
    log: (line) => ref.read(bikeLogProvider.notifier).add(line),
  );
});

/// Com bikes na lista, a busca termina depois deste tempo sem bike nova.
final fleetScanQuietPeriodProvider = Provider(
  (ref) => const Duration(seconds: 3),
);

enum FleetStep {
  connecting('Conectando…'),
  authenticating('Autenticando com a senha padrão…'),
  identifying('Lendo modelo e funcionalidades…'),
  settingGear('Reduzindo a marcha…'),
  locking('Travando…'),
  disconnecting('Desconectando…');

  const FleetStep(this.label);
  final String label;
}

/// Um ciclo da operação contínua e as bikes acionadas (ou vistas pela
/// primeira vez, se bloqueadas) nele. O do ciclo atual é atualizado ao vivo;
/// os anteriores ficam como histórico.
///
/// Ciclos seguidos sem nada a fazer viram um registro só ([number] até
/// [lastNumber]), para a lista não crescer sem fim.
class FleetCycleLog {
  const FleetCycleLog({
    required this.number,
    required this.startedAt,
    required this.bikes,
    int? lastNumber,
    DateTime? lastStartedAt,
  }) : lastNumber = lastNumber ?? number,
       lastStartedAt = lastStartedAt ?? startedAt;

  final int number;
  final DateTime startedAt;
  final List<FleetBike> bikes;

  /// Último ciclo do grupo (igual a [number] quando é um ciclo só).
  final int lastNumber;
  final DateTime lastStartedAt;

  bool get isEmpty => bikes.isEmpty;
  bool get isRange => lastNumber > number;

  FleetCycleLog withBikes(List<FleetBike> bikes) =>
      FleetCycleLog(number: number, startedAt: startedAt, bikes: bikes);

  /// Junta mais um ciclo vazio a este grupo de ciclos vazios.
  FleetCycleLog extendedTo(int cycle, DateTime at) => FleetCycleLog(
    number: number,
    startedAt: startedAt,
    bikes: const [],
    lastNumber: cycle,
    lastStartedAt: at,
  );
}

class FleetState {
  const FleetState({
    this.bikes = const [],
    this.isRefreshing = false,
    this.isRunning = false,
    this.isContinuous = false,
    this.cycle = 0,
    this.cycleLog = const [],
    this.activeBikeId,
    this.activeStep,
    this.processed = 0,
    this.total = 0,
    this.summary,
    this.error,
  });

  final List<FleetBike> bikes;

  /// Busca Bluetooth em andamento.
  final bool isRefreshing;
  final bool isRunning;

  /// "Operação contínua": repete busca + ações até parar.
  final bool isContinuous;

  /// Ciclo atual da operação contínua (começa em 1).
  final int cycle;

  /// Histórico da operação contínua (ciclos vazios seguidos agrupados).
  final List<FleetCycleLog> cycleLog;
  final String? activeBikeId;
  final FleetStep? activeStep;
  final int processed;
  final int total;

  /// Resumo da última operação (ex.: "6 concluídas, 2 com falha").
  final String? summary;
  final String? error;

  int count(FleetBikeStatus s) => bikes.where((b) => b.status == s).length;

  FleetState copyWith({
    List<FleetBike>? bikes,
    bool? isRefreshing,
    bool? isRunning,
    bool? isContinuous,
    int? cycle,
    List<FleetCycleLog>? cycleLog,
    String? activeBikeId,
    FleetStep? activeStep,
    int? processed,
    int? total,
    String? summary,
    String? error,
    bool clearActive = false,
    bool clearSummary = false,
    bool clearError = false,
  }) {
    return FleetState(
      bikes: bikes ?? this.bikes,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRunning: isRunning ?? this.isRunning,
      isContinuous: isContinuous ?? this.isContinuous,
      cycle: cycle ?? this.cycle,
      cycleLog: cycleLog ?? this.cycleLog,
      activeBikeId: clearActive ? null : (activeBikeId ?? this.activeBikeId),
      activeStep: clearActive ? null : (activeStep ?? this.activeStep),
      processed: processed ?? this.processed,
      total: total ?? this.total,
      summary: clearSummary ? null : (summary ?? this.summary),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final fleetControllerProvider = NotifierProvider<FleetController, FleetState>(
  FleetController.new,
);

class _Cancelled implements Exception {}

/// Uma operação em andamento. "Parar" cancela na hora: toda etapa aguardada
/// por [guard] termina imediatamente com [_Cancelled].
class _Run {
  final _stop = Completer<void>();

  bool get cancelled => _stop.isCompleted;

  void cancel() {
    if (!cancelled) _stop.complete();
  }

  Future<T> guard<T>(Future<T> f) {
    if (cancelled) return Future.error(_Cancelled());
    return Future.any([f, _stop.future.then<T>((_) => throw _Cancelled())]);
  }
}

class FleetController extends Notifier<FleetState> {
  _Run? _run;

  /// Desconexão da bike que estava ativa quando alguém parou. Uma nova
  /// operação espera por ela antes de conectar em outra bike.
  Future<void> _cleanup = Future.value();

  // Busca em andamento.
  Completer<Set<String>>? _scanDone;
  Set<String> _scanSeen = const {};
  StreamSubscription<List<FleetBike>>? _scanSub;
  Timer? _scanLimit;
  Timer? _scanQuiet;
  BikeFleetGateway? _scanGateway;

  /// Fixado durante uma operação, para trocar o modo simulação no meio não
  /// misturar as fontes.
  BikeFleetGateway? _runGateway;

  BikeFleetGateway get _gateway =>
      _runGateway ?? ref.read(bikeFleetGatewayProvider);

  bool _blocked(String id) => ref.read(fleetBlocklistProvider).containsKey(id);

  @override
  FleetState build() {
    ref.onDispose(() {
      _run?.cancel();
      _endScan();
    });
    // Trocou simulação ↔ Bluetooth: refaz a lista com a nova fonte.
    ref.listen(bikeFleetGatewayProvider, (_, _) {
      if (state.isRunning) return;
      _endScan();
      _set(state.copyWith(bikes: const [], clearSummary: true));
      unawaited(refresh());
    });
    Future.microtask(refresh);
    return const FleetState(isRefreshing: true);
  }

  /// Busca as bikes de novo, mantendo o resultado das que já estavam na lista.
  Future<void> refresh() async {
    if (state.isRunning) return;
    await _scan();
  }

  /// Termina quando: [AppSettings.scanSeconds] se passarem, ou houver bikes
  /// e [fleetScanQuietPeriodProvider] passar sem bike nova, ou alguém parar.
  /// Devolve os ids vistos nesta busca.
  ///
  /// [accumulate]: mantém na lista as bikes de buscas anteriores e acrescenta
  /// as novas no fim (modo contínuo). Senão, a lista recomeça vazia.
  Future<Set<String>> _scan({bool accumulate = false}) {
    if (_scanDone case final running?) return running.future;
    final done = Completer<Set<String>>();
    _scanDone = done;
    final seen = _scanSeen = <String>{};

    final settings = ref.read(appSettingsProvider);
    final gateway = _scanGateway = _gateway;
    final quiet = ref.read(fleetScanQuietPeriodProvider);
    final previous = {for (final b in state.bikes) b.id: b};
    _set(
      state.copyWith(
        isRefreshing: true,
        bikes: accumulate ? null : const [],
        clearError: true,
      ),
    );

    _scanLimit = Timer(Duration(seconds: settings.scanSeconds), _endScan);
    _scanSub = gateway.discover().listen(
      (found) {
        final grew = found.any((b) => !seen.contains(b.id));
        seen.addAll(found.map((b) => b.id));
        _set(state.copyWith(bikes: _merge(found, previous, accumulate)));
        if (grew) {
          _scanQuiet?.cancel();
          _scanQuiet = Timer(quiet, _endScan);
        }
      },
      onError: (Object e) => _endScan(error: 'Falha na busca: $e'),
      onDone: _endScan,
    );
    return done.future;
  }

  /// Junta o resultado da busca com o que já se sabia de cada bike.
  List<FleetBike> _merge(
    List<FleetBike> found,
    Map<String, FleetBike> previous,
    bool accumulate,
  ) {
    FleetBike keep(FleetBike b, FleetBike old) => b.copyWith(
      model: old.model,
      features: old.features,
      status: old.status,
      message: old.message,
    );
    if (!accumulate) {
      return [
        for (final b in found)
          if (previous[b.id] case final old?) keep(b, old) else b,
      ];
    }
    final byId = {for (final b in found) b.id: b};
    final current = state.bikes;
    final known = {for (final b in current) b.id};
    return [
      // Bikes já listadas ficam no lugar (só o sinal é atualizado).
      for (final b in current)
        if (byId[b.id] case final f?) b.copyWith(rssi: f.rssi) else b,
      for (final b in found)
        if (!known.contains(b.id)) b,
    ];
  }

  void _endScan({String? error}) {
    final done = _scanDone;
    if (done == null) return;
    _scanDone = null;
    _scanLimit?.cancel();
    _scanQuiet?.cancel();
    unawaited(_scanSub?.cancel());
    _scanSub = null;
    unawaited(_scanGateway?.stopDiscovery());
    _scanGateway = null;
    _set(state.copyWith(isRefreshing: false, error: error));
    done.complete(_scanSeen);
  }

  _Run? _begin({required bool continuous}) {
    if (_run != null) return null;
    if (ref.read(bikeControllerProvider).phase != BikePhase.disconnected) {
      _set(
        state.copyWith(
          error: 'Desconecte a bike da aba Veículo antes de iniciar.',
        ),
      );
      return null;
    }
    final run = _run = _Run();
    _runGateway = ref.read(bikeFleetGatewayProvider);
    // Sempre do zero: lista limpa e busca nova.
    _endScan();
    _set(
      state.copyWith(
        isRunning: true,
        isContinuous: continuous,
        processed: 0,
        total: 0,
        cycle: 0,
        cycleLog: const [],
        bikes: const [],
        clearActive: true,
        clearSummary: true,
        clearError: true,
      ),
    );
    return run;
  }

  /// Espera a desconexão de uma operação parada (no máximo alguns segundos).
  Future<void> _awaitCleanup() =>
      _cleanup.timeout(const Duration(seconds: 5), onTimeout: () {});

  /// Uma passada: limpa a lista, busca, e para cada bike (menos as
  /// bloqueadas) conecta, autentica com a senha padrão, lê o modelo, envia a
  /// marcha configurada, trava (se ligado nas Configurações e a bike tiver
  /// trava) e desconecta. Uma de cada vez.
  Future<void> start() async {
    final run = _begin(continuous: false);
    if (run == null) return;
    final settings = ref.read(appSettingsProvider);

    await _awaitCleanup();
    if (run.cancelled) return;
    await _scan();
    if (run.cancelled || !ref.mounted) return;
    if (state.bikes.isEmpty) {
      return _finish(
        run,
        'Nenhuma bicicleta encontrada em ${settings.scanSeconds} s.',
      );
    }

    final queue = [
      for (final b in state.bikes)
        if (!_blocked(b.id)) b.id,
    ];
    _set(state.copyWith(total: queue.length));

    for (final id in queue) {
      if (run.cancelled) return;
      // Pode ter sido bloqueada depois de a operação começar.
      if (!_blocked(id)) await _process(run, id, settings);
      if (run.cancelled) return;
      _set(state.copyWith(processed: state.processed + 1));
    }
    _finish(run, _summary());
  }

  /// Repete busca + processamento até alguém tocar em "Parar".
  ///
  /// Bikes concluídas nesta operação não são acionadas de novo; as que
  /// falharam são tentadas outra vez no próximo ciclo em que aparecerem.
  /// Bloqueadas são puladas. As Configurações são relidas a cada ciclo.
  Future<void> startContinuous() async {
    final run = _begin(continuous: true);
    if (run == null) return;
    await _awaitCleanup();

    final completed = <String>{};
    final logged = <String>{};
    while (!run.cancelled && ref.mounted) {
      final settings = ref.read(appSettingsProvider);
      final cycle = state.cycle + 1;
      final startedAt = DateTime.now();
      _set(state.copyWith(cycle: cycle, clearActive: true));
      final seen = await _scan(accumulate: true);
      if (run.cancelled || !ref.mounted) return;

      final queue = [
        for (final b in state.bikes)
          if (seen.contains(b.id) &&
              !completed.contains(b.id) &&
              !_blocked(b.id))
            b.id,
      ];
      // Bloqueadas entram no histórico só na primeira vez em que aparecem.
      final firstBlocked = [
        for (final b in state.bikes)
          if (seen.contains(b.id) && _blocked(b.id) && !logged.contains(b.id))
            b.id,
      ];
      final entries = {...queue, ...firstBlocked};
      if (entries.isEmpty) {
        // Nada a fazer: registra como "nada novo", juntando com o anterior
        // se ele também foi vazio.
        final log = state.cycleLog;
        _set(
          state.copyWith(
            cycleLog: log.isNotEmpty && log.last.isEmpty
                ? [
                    ...log.take(log.length - 1),
                    log.last.extendedTo(cycle, startedAt),
                  ]
                : [
                    ...log,
                    FleetCycleLog(
                      number: cycle,
                      startedAt: startedAt,
                      bikes: const [],
                    ),
                  ],
          ),
        );
      } else {
        logged.addAll(entries);
        _set(
          state.copyWith(
            cycleLog: [
              ...state.cycleLog,
              FleetCycleLog(
                number: cycle,
                startedAt: startedAt,
                bikes: [
                  for (final b in state.bikes)
                    if (entries.contains(b.id))
                      // Nova tentativa começa limpa neste ciclo.
                      queue.contains(b.id)
                          ? b.copyWith(
                              status: FleetBikeStatus.disconnected,
                              clearMessage: true,
                            )
                          : b,
                ],
              ),
            ],
          ),
        );
      }

      for (final id in queue) {
        if (run.cancelled) return;
        if (_blocked(id)) continue;
        await _process(run, id, settings);
        if (run.cancelled) return;
        final ok = state.bikes.any(
          (b) => b.id == id && b.status == FleetBikeStatus.completed,
        );
        if (ok) completed.add(id);
        _set(state.copyWith(processed: state.processed + 1));
      }
    }
  }

  /// Para tudo na hora: a busca e a etapa em andamento são abandonadas e a
  /// bike ativa é desconectada em segundo plano.
  void stop() {
    final run = _run;
    if (run == null) return;
    run.cancel();
    _run = null;
    _endScan();

    final active = state.activeBikeId;
    final gateway = _gateway;
    _runGateway = null;
    if (active != null) {
      _cleanup = gateway.disconnect(active).catchError((Object _) {});
      _updateBike(
        active,
        (b) => b.status == FleetBikeStatus.completed
            ? b
            : b.copyWith(
                status: FleetBikeStatus.disconnected,
                message: 'Interrompida.',
              ),
      );
    }
    _set(
      state.copyWith(
        isRunning: false,
        isRefreshing: false,
        clearActive: true,
        summary: state.isContinuous
            ? 'Operação contínua parada após ${state.cycle} ciclo(s): '
                  '${_counts()}.'
            : 'Interrompida. ${_summary()}',
      ),
    );
  }

  String _counts() {
    final blocked = state.bikes.where((b) => _blocked(b.id)).length;
    return '${state.count(FleetBikeStatus.completed)} concluída(s), '
        '${state.count(FleetBikeStatus.failed)} com falha'
        '${blocked > 0 ? ', $blocked bloqueada(s) pulada(s)' : ''}';
  }

  String _summary() {
    final pending = state.total - state.processed;
    return '${_counts()}'
        '${pending > 0 ? ', $pending não processada(s)' : ''}.';
  }

  void _finish(_Run run, String summary) {
    if (run.cancelled) return;
    _run = null;
    _runGateway = null;
    _set(state.copyWith(isRunning: false, clearActive: true, summary: summary));
  }

  /// Uma bike, com novas tentativas. Se a operação for parada, sai na hora
  /// sem mexer na tela (o [stop] já cuidou disso).
  Future<void> _process(_Run run, String id, AppSettings s) async {
    final timeout = Duration(seconds: s.timeoutSeconds);
    final attempts = s.retries + 1;
    String? lastError;

    Future<T> step<T>(FleetStep step, Future<T> Function() action) {
      if (run.cancelled) throw _Cancelled();
      _set(state.copyWith(activeBikeId: id, activeStep: step));
      return run.guard(action().timeout(timeout));
    }

    Future<void> disconnect() => step(
      FleetStep.disconnecting,
      () => _gateway.disconnect(id).catchError((Object _) {}),
    );

    try {
      for (var attempt = 1; attempt <= attempts; attempt++) {
        try {
          await step(FleetStep.connecting, () => _gateway.connect(id));
          _setBike(id, FleetBikeStatus.connected);
          await step(
            FleetStep.authenticating,
            () => _gateway.authenticate(id, s.defaultPassword),
          );
          final details = await step(
            FleetStep.identifying,
            () => _gateway.identify(id),
          );
          _setDetails(id, details);
          await step(
            FleetStep.settingGear,
            () => _gateway.setGear(id, s.targetGear),
          );
          final hasLock = details.features.contains(BikeFeature.lock);
          if (s.lockBikes && hasLock) {
            await step(FleetStep.locking, () => _gateway.lock(id));
          }
          await disconnect();
          final gear = 'Marcha ajustada para ${s.targetGear}';
          if (s.soundOnSuccess) {
            unawaited(ref.read(successSoundProvider).play(s.successSound));
          }
          _setBike(
            id,
            FleetBikeStatus.completed,
            message: !s.lockBikes
                ? '$gear.'
                : hasLock
                ? '$gear e bike travada.'
                : '$gear (sem trava).',
          );
          return;
        } on TimeoutException {
          lastError = 'Tempo esgotado (${s.timeoutSeconds} s).';
        } on FleetFailure catch (e) {
          lastError = e.message;
        } on _Cancelled {
          rethrow;
        } catch (e) {
          lastError = 'Erro inesperado: $e';
        }

        // Também cancela uma conexão que ainda estava em andamento.
        await disconnect();
        if (attempt < attempts) {
          _setBike(
            id,
            FleetBikeStatus.disconnected,
            message: 'Tentativa $attempt falhou: $lastError',
          );
        }
      }
      final tries = attempts > 1 ? ' ($attempts tentativas)' : '';
      _setBike(id, FleetBikeStatus.failed, message: '$lastError$tries');
    } on _Cancelled {
      return;
    }
  }

  void _setBike(String id, FleetBikeStatus status, {String? message}) {
    _updateBike(
      id,
      (b) => b.copyWith(
        status: status,
        message: message,
        clearMessage: message == null,
      ),
    );
  }

  void _setDetails(String id, FleetBikeDetails d) {
    _updateBike(
      id,
      (b) => b.copyWith(
        model: d.model,
        features: d.features.isEmpty ? null : d.features,
      ),
    );
  }

  /// Atualiza a bike na lista e, na operação contínua, também no ciclo atual
  /// do histórico (os ciclos anteriores não mudam).
  void _updateBike(String id, FleetBike Function(FleetBike) change) {
    final log = state.cycleLog;
    final current = log.isNotEmpty && log.last.number == state.cycle
        ? log.last
        : null;
    _set(
      state.copyWith(
        bikes: [for (final b in state.bikes) b.id == id ? change(b) : b],
        cycleLog: current == null
            ? null
            : [
                ...log.take(log.length - 1),
                current.withBikes([
                  for (final b in current.bikes) b.id == id ? change(b) : b,
                ]),
              ],
      ),
    );
  }

  void _set(FleetState next) {
    if (ref.mounted) state = next;
  }
}
