import '../../../../core/constants/app_constants.dart';

/// Parâmetros da aplicação usados pela operação em lote das bicicletas.
class AppSettings {
  const AppSettings({
    this.defaultPassword = AppConstants.defaultPassword,
    this.targetGear = 0,
    this.timeoutSeconds = 15,
    this.retries = 1,
    this.scanSeconds = 10,
    this.lockBikes = true,
    this.useMock = false,
    this.keepScreenOn = false,
  });

  /// Senha Bluetooth (6 dígitos) tentada em cada bike.
  final String defaultPassword;

  /// Marcha enviada pela operação (`+MODE=n`).
  final int targetGear;

  /// Tempo máximo de cada etapa (conectar, autenticar, enviar comando).
  final int timeoutSeconds;

  /// Novas tentativas antes de marcar a bike como Falha.
  final int retries;

  /// Tempo máximo da busca quando nenhuma bike aparece.
  final int scanSeconds;

  /// Travar (`+LOCK=1`) as bikes que tiverem trava, depois da marcha.
  final bool lockBikes;

  /// Bicicletas simuladas no lugar do Bluetooth (para ver o comportamento).
  final bool useMock;

  /// Não deixar a tela apagar enquanto a operação roda.
  final bool keepScreenOn;

  static const gearRange = (min: 0, max: 5);
  static const timeoutRange = (min: 5, max: 30);
  static const retriesRange = (min: 0, max: 3);
  static const scanRange = (min: 5, max: 30);

  static bool isValidPassword(String v) => RegExp(r'^\d{6}$').hasMatch(v);

  AppSettings copyWith({
    String? defaultPassword,
    int? targetGear,
    int? timeoutSeconds,
    int? retries,
    int? scanSeconds,
    bool? lockBikes,
    bool? useMock,
    bool? keepScreenOn,
  }) {
    return AppSettings(
      defaultPassword: defaultPassword ?? this.defaultPassword,
      targetGear: targetGear ?? this.targetGear,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      retries: retries ?? this.retries,
      scanSeconds: scanSeconds ?? this.scanSeconds,
      lockBikes: lockBikes ?? this.lockBikes,
      useMock: useMock ?? this.useMock,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }

  Map<String, Object> toMap() => {
    'defaultPassword': defaultPassword,
    'targetGear': targetGear,
    'timeoutSeconds': timeoutSeconds,
    'retries': retries,
    'scanSeconds': scanSeconds,
    'lockBikes': lockBikes,
    'useMock': useMock,
    'keepScreenOn': keepScreenOn,
  };

  /// Lê o que estiver salvo; valores ausentes ou inválidos voltam ao padrão.
  factory AppSettings.fromMap(Map<dynamic, dynamic> m) {
    const d = AppSettings();
    final pwd = m['defaultPassword'];
    final lock = m['lockBikes'];
    final mock = m['useMock'];
    final awake = m['keepScreenOn'];
    int read(String key, int fallback, ({int min, int max}) range) {
      final v = m[key];
      return v is int && v >= range.min && v <= range.max ? v : fallback;
    }

    return AppSettings(
      defaultPassword: pwd is String && isValidPassword(pwd)
          ? pwd
          : d.defaultPassword,
      targetGear: read('targetGear', d.targetGear, gearRange),
      timeoutSeconds: read('timeoutSeconds', d.timeoutSeconds, timeoutRange),
      retries: read('retries', d.retries, retriesRange),
      scanSeconds: read('scanSeconds', d.scanSeconds, scanRange),
      lockBikes: lock is bool ? lock : d.lockBikes,
      useMock: mock is bool ? mock : d.useMock,
      keepScreenOn: awake is bool ? awake : d.keepScreenOn,
    );
  }
}
