import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/screen_awake.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../app_settings/presentation/providers/app_settings_providers.dart';
import '../../../bike/presentation/widgets/section.dart';
import '../../domain/entities/fleet_bike.dart';
import '../providers/fleet_blocklist_providers.dart';
import '../providers/fleet_providers.dart';
import '../widgets/fleet_bike_card.dart';

/// Aba "Bicicletas": operação em lote sobre as bikes ao alcance.
class FleetScreen extends ConsumerStatefulWidget {
  const FleetScreen({super.key});

  @override
  ConsumerState<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends ConsumerState<FleetScreen> {
  final _cardKeys = <String, GlobalKey>{};

  /// Último pedido feito ao sistema (evita chamadas repetidas).
  bool _awake = false;
  late final ScreenAwake _screen = ref.read(screenAwakeProvider);

  /// Tela acesa só com o interruptor ligado E a operação rodando.
  void _syncScreenAwake({required bool keepOn, required bool running}) {
    final want = keepOn && running;
    if (want == _awake) return;
    _awake = want;
    _screen.set(on: want);
  }

  @override
  void dispose() {
    if (_awake) _screen.set(on: false);
    super.dispose();
  }

  GlobalKey _keyFor(String key) => _cardKeys.putIfAbsent(key, GlobalKey.new);

  /// Chave do cartão: na operação contínua, a mesma bike pode aparecer em
  /// vários ciclos.
  static String _cardKey(FleetState s, String bikeId) =>
      s.isContinuous && s.cycleLog.isNotEmpty ? '${s.cycle}:$bikeId' : bikeId;

  /// Rola a lista até o cartão (depois do próximo frame, quando ele existe).
  void _follow(String key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cardKeys[key]?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(fleetControllerProvider);
    final c = ref.read(fleetControllerProvider.notifier);
    final mock = ref.watch(appSettingsProvider.select((s) => s.useMock));
    final blocklist = ref.watch(fleetBlocklistProvider);
    final keepOn = ref.watch(appSettingsProvider.select((s) => s.keepScreenOn));
    _syncScreenAwake(keepOn: keepOn, running: s.isRunning);

    ref
      ..listen(fleetControllerProvider.select((s) => s.error), (_, err) {
        if (err != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(err)));
        }
      })
      // Acompanha a bike que está sendo acionada.
      ..listen(fleetControllerProvider.select((s) => s.activeBikeId), (
        prev,
        id,
      ) {
        if (id != null && id != prev) {
          _follow(_cardKey(ref.read(fleetControllerProvider), id));
        }
      })
      // Na operação contínua, mostra o separador de cada ciclo novo.
      ..listen(fleetControllerProvider.select((s) => s.cycleLog.length), (
        prev,
        len,
      ) {
        final st = ref.read(fleetControllerProvider);
        if (st.isRunning && len > (prev ?? 0) && !st.cycleLog.last.isEmpty) {
          _follow('cycle:${st.cycleLog.last.number}');
        }
      });

    Widget card(FleetBike b, {required String key, required bool live}) =>
        FleetBikeCard(
          key: _keyFor(key),
          bike: b,
          activeStep: live && b.id == s.activeBikeId ? s.activeStep : null,
          blocked: blocklist.containsKey(b.id),
          onToggleBlock: () =>
              ref.read(fleetBlocklistProvider.notifier).toggle(b.id, b.name),
        );
    final showLog = s.isContinuous && s.cycleLog.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bicicletas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            icon: const Icon(Icons.refresh),
            onPressed: s.isRunning || s.isRefreshing ? null : c.refresh,
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.appSettings),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.text,
        backgroundColor: AppColors.yellow,
        onRefresh: s.isRunning ? () async {} : c.refresh,
        // Coluna (e não ListView) para todos os cartões existirem e a
        // rolagem automática conseguir chegar em qualquer um.
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mock) const _MockBanner(),
              _OperationCard(
                state: s,
                onStart: c.start,
                onStartContinuous: c.startContinuous,
                onStop: c.stop,
              ),
              SectionTitle(
                showLog
                    ? 'Histórico por ciclo (${s.bikes.length} bicicleta(s) '
                          'vistas)'
                    : s.isRefreshing
                    ? 'Buscando bicicletas…'
                    : 'Bicicletas encontradas (${s.bikes.length})',
              ),
              if (showLog)
                for (final log in s.cycleLog) ...[
                  if (log.isEmpty)
                    _EmptyCycles(log: log)
                  else
                    _CycleHeader(key: _keyFor('cycle:${log.number}'), log: log),
                  for (final b in log.bikes)
                    card(
                      b,
                      key: '${log.number}:${b.id}',
                      live: log.number == s.cycle,
                    ),
                ]
              else if (s.isRefreshing && s.bikes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (s.bikes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Nenhuma bicicleta encontrada.\n'
                    'Puxe para buscar de novo ou toque em Iniciar operação.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                for (final b in s.bikes) card(b, key: b.id, live: true),
            ],
          ),
        ),
      ),
    );
  }
}

String _time(DateTime t) =>
    [t.hour, t.minute, t.second].map((v) => '$v'.padLeft(2, '0')).join(':');

/// Linha discreta para ciclos (um ou vários seguidos) sem nada a fazer.
class _EmptyCycles extends StatelessWidget {
  const _EmptyCycles({required this.log});

  final FleetCycleLog log;

  @override
  Widget build(BuildContext context) {
    final label = log.isRange
        ? 'Ciclos ${log.number}–${log.lastNumber} · '
              '${_time(log.startedAt)}–${_time(log.lastStartedAt)} · nada novo'
        : 'Ciclo ${log.number} · ${_time(log.startedAt)} · nada novo';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.more_horiz, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
        ],
      ),
    );
  }
}

/// Quebra entre ciclos da operação contínua.
class _CycleHeader extends StatelessWidget {
  const _CycleHeader({super.key, required this.log});

  final FleetCycleLog log;

  @override
  Widget build(BuildContext context) {
    final done = log.bikes
        .where((b) => b.status == FleetBikeStatus.completed)
        .length;
    final failed = log.bikes
        .where((b) => b.status == FleetBikeStatus.failed)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Ciclo ${log.number}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_time(log.startedAt)} · ${log.bikes.length} bicicleta(s)'
              '${done > 0 ? ' · $done ok' : ''}'
              '${failed > 0 ? ' · $failed falha' : ''}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }
}

class _MockBanner extends StatelessWidget {
  const _MockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5CC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: Color(0xFF8A6D00)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo simulação: bicicletas fictícias, nenhum comando é '
              'enviado. Desligue em Configurações.',
              style: TextStyle(color: Color(0xFF8A6D00), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationCard extends ConsumerWidget {
  const _OperationCard({
    required this.state,
    required this.onStart,
    required this.onStartContinuous,
    required this.onStop,
  });

  final FleetState state;
  final VoidCallback onStart;
  final VoidCallback onStartContinuous;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final s = state;
    final canStart = !s.isRunning;
    const green = Color(0xFF2E7D32);

    final (dot, title) = switch (s) {
      FleetState(isRunning: true, isContinuous: true, isRefreshing: true) => (
        green,
        'Contínua · ciclo ${s.cycle} · buscando…',
      ),
      FleetState(isRunning: true, isContinuous: true) => (
        green,
        'Contínua · ciclo ${s.cycle}',
      ),
      FleetState(isRunning: true, total: 0) => (green, 'Buscando bicicletas…'),
      FleetState(isRunning: true) => (green, 'Em execução'),
      _ => (AppColors.muted, 'Parada'),
    };

    final String? counter = !s.isRunning
        ? null
        : s.isContinuous
        ? '${s.processed} acionamento(s)'
        : s.total > 0
        ? '${s.processed} de ${s.total}'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pulse(color: dot, animate: s.isRunning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (counter != null)
                  Text(counter, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reduz a marcha para ${settings.targetGear}'
              '${settings.lockBikes ? ' e trava as que tiverem trava' : ''}, '
              'usando a senha padrão, uma bicicleta por vez.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (s.isRunning) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  // Contínua não tem fim: barra indeterminada.
                  value: s.isContinuous || s.total == 0
                      ? null
                      : s.processed / s.total,
                  minHeight: 6,
                  color: AppColors.yellow,
                  backgroundColor: const Color(0xFFEDEDF0),
                ),
              ),
              if (s.isContinuous) ...[
                const SizedBox(height: 8),
                Text(
                  '${s.count(FleetBikeStatus.completed)} concluída(s) · '
                  '${s.count(FleetBikeStatus.failed)} com falha',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ] else if (s.summary != null) ...[
              const SizedBox(height: 12),
              Text(s.summary!, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: canStart ? onStart : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar operação'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.yellow, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: canStart ? onStartContinuous : null,
                icon: const Icon(Icons.all_inclusive),
                label: const Text('Iniciar operação contínua'),
              ),
            ),
            const SizedBox(height: 12),
            _KeepScreenOnSwitch(running: s.isRunning),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: s.isRunning ? onStop : null,
                icon: const Icon(Icons.stop),
                label: const Text('Parar operação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepScreenOnSwitch extends ConsumerWidget {
  const _KeepScreenOnSwitch({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final on = settings.keepScreenOn;
    return Row(
      children: [
        Icon(
          on ? Icons.light_mode : Icons.light_mode_outlined,
          color: on ? AppColors.text : AppColors.muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manter tela ligada',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                !on
                    ? 'A tela pode apagar durante a operação'
                    : running
                    ? 'Tela acesa até a operação parar'
                    : 'A tela não vai apagar durante a operação',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: on,
          onChanged: (v) => ref
              .read(appSettingsProvider.notifier)
              .update(settings.copyWith(keepScreenOn: v)),
        ),
      ],
    );
  }
}

/// Bolinha de status; pulsa enquanto a operação roda.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.color, required this.animate});

  final Color color;
  final bool animate;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animate) {
      _ctrl
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
