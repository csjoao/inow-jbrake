enum BikePhase {
  disconnected,
  connecting,

  /// Conectado no Bluetooth, fazendo a autenticação e enviando a senha.
  authenticating,
  connected,
}

class LogLine {
  LogLine(this.outgoing, this.text) : at = DateTime.now();

  /// `true` = app → bike; `false` = bike → app.
  final bool outgoing;
  final String text;
  final DateTime at;
}

/// Dados de "Informações do veículo", "Sistema" e "Pedalada".
class BikeInfo {
  const BikeInfo({
    this.voltage,
    this.current,
    this.chargeCycles,
    this.software,
    this.firmware,
    this.rideDistance,
    this.rideTopSpeed,
    this.rideSeconds,
    this.totalDistance,
    this.totalSeconds,
  });

  final double? voltage;
  final double? current;
  final int? chargeCycles;
  final double? software;
  final double? firmware;
  final double? rideDistance;
  final double? rideTopSpeed;
  final int? rideSeconds;
  final double? totalDistance;
  final int? totalSeconds;

  /// Mesma estimativa do app oficial: V × A × 0,8.
  double? get power =>
      (voltage != null && current != null) ? voltage! * current! * 0.8 : null;

  /// km/h médio da pedalada atual.
  double? get rideAverageSpeed =>
      (rideDistance != null && rideSeconds != null && rideSeconds! > 0)
      ? rideDistance! * 3600 / rideSeconds!
      : null;

  BikeInfo merge({
    double? voltage,
    double? current,
    int? chargeCycles,
    double? software,
    double? firmware,
    double? rideDistance,
    double? rideTopSpeed,
    int? rideSeconds,
    double? totalDistance,
    int? totalSeconds,
  }) {
    return BikeInfo(
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      chargeCycles: chargeCycles ?? this.chargeCycles,
      software: software ?? this.software,
      firmware: firmware ?? this.firmware,
      rideDistance: rideDistance ?? this.rideDistance,
      rideTopSpeed: rideTopSpeed ?? this.rideTopSpeed,
      rideSeconds: rideSeconds ?? this.rideSeconds,
      totalDistance: totalDistance ?? this.totalDistance,
      totalSeconds: totalSeconds ?? this.totalSeconds,
    );
  }
}

enum NfcPairing { idle, waitingCard, success, alreadyBound, failed }

class BikeState {
  const BikeState({
    this.phase = BikePhase.disconnected,
    this.deviceId,
    this.name,
    this.model,
    this.speed = 0,
    this.battery,
    this.trip,
    this.odo,
    this.mode,
    this.maxMode = 5,
    this.locked,
    this.headlight,
    this.telemetryFormats = const {},
    this.values = const {},
    this.info = const BikeInfo(),
    this.nfcCards = const [],
    this.nfcPairing = NfcPairing.idle,
    this.error,
  });

  final BikePhase phase;
  final String? deviceId;
  final String? name;

  /// Resposta do `GETDEVID`, ex.: `imoogoo-inow05`.
  final String? model;
  final double speed;
  final int? battery;
  final double? trip;
  final double? odo;
  final int? mode;
  final int maxMode;
  final bool? locked;
  final bool? headlight;

  /// Formatos de pacote binário já recebidos desta bike.
  final Set<String> telemetryFormats;

  /// Últimas respostas `CHAVE=valor` recebidas (CHAVE → valor).
  final Map<String, String> values;
  final BikeInfo info;
  final List<String> nfcCards;
  final NfcPairing nfcPairing;
  final String? error;

  bool get isConnected => phase == BikePhase.connected;

  BikeState copyWith({
    BikePhase? phase,
    String? deviceId,
    String? name,
    String? model,
    double? speed,
    int? battery,
    double? trip,
    double? odo,
    int? mode,
    int? maxMode,
    bool? locked,
    bool? headlight,
    Set<String>? telemetryFormats,
    Map<String, String>? values,
    BikeInfo? info,
    List<String>? nfcCards,
    NfcPairing? nfcPairing,
    String? error,
    bool clearError = false,
  }) {
    return BikeState(
      phase: phase ?? this.phase,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      model: model ?? this.model,
      speed: speed ?? this.speed,
      battery: battery ?? this.battery,
      trip: trip ?? this.trip,
      odo: odo ?? this.odo,
      mode: mode ?? this.mode,
      maxMode: maxMode ?? this.maxMode,
      locked: locked ?? this.locked,
      headlight: headlight ?? this.headlight,
      telemetryFormats: telemetryFormats ?? this.telemetryFormats,
      values: values ?? this.values,
      info: info ?? this.info,
      nfcCards: nfcCards ?? this.nfcCards,
      nfcPairing: nfcPairing ?? this.nfcPairing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
