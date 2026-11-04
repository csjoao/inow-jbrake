/// Estado de cada bicicleta na operação em lote.
enum FleetBikeStatus {
  disconnected('Desconectada'),
  connected('Conectada'),
  completed('Operação concluída'),
  failed('Falha');

  const FleetBikeStatus(this.label);
  final String label;
}

/// Funcionalidades que a bike anuncia (vêm do modelo / `GETDEVID`).
enum BikeFeature {
  gear('Marcha'),
  lock('Trava'),
  headlight('Farol'),
  nfc('NFC'),
  cruise('Cruise');

  const BikeFeature(this.label);
  final String label;
}

class FleetBike {
  const FleetBike({
    required this.id,
    required this.name,
    this.model,
    this.features = const [],
    this.rssi,
    this.status = FleetBikeStatus.disconnected,
    this.message,
  });

  /// Endereço / remoteId do Bluetooth.
  final String id;
  final String name;

  /// Ex.: `imoogoo-inow05`. Só é conhecido depois de conectar.
  final String? model;

  /// Detectadas depois de conectar (vazio antes disso).
  final List<BikeFeature> features;

  /// Intensidade do sinal na última busca (dBm).
  final int? rssi;
  final FleetBikeStatus status;

  /// Detalhe do último resultado (ex.: motivo da falha).
  final String? message;

  FleetBike copyWith({
    String? name,
    String? model,
    List<BikeFeature>? features,
    int? rssi,
    FleetBikeStatus? status,
    String? message,
    bool clearMessage = false,
  }) {
    return FleetBike(
      id: id,
      name: name ?? this.name,
      model: model ?? this.model,
      features: features ?? this.features,
      rssi: rssi ?? this.rssi,
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
