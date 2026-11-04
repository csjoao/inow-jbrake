import '../entities/fleet_bike.dart';

/// Erro esperado de uma etapa (vira a tag "Falha" com esta mensagem).
class FleetFailure implements Exception {
  const FleetFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// O que a bike informou depois de autenticada.
class FleetBikeDetails {
  const FleetBikeDetails({this.model, this.features = const []});

  /// Resposta do `GETDEVID`, ex.: `imoogoo-inow05`.
  final String? model;
  final List<BikeFeature> features;
}

/// Acesso às bicicletas usado pela operação em lote. Uma bike por vez.
///
/// Implementações: [BleBikeFleetGateway] (Bluetooth real) e
/// [MockBikeFleetGateway] (simulada, para testes).
abstract interface class BikeFleetGateway {
  /// Inicia a busca. Emite a lista completa a cada bike nova e só termina
  /// com [stopDiscovery]. Status sempre [FleetBikeStatus.disconnected].
  Stream<List<FleetBike>> discover();

  Future<void> stopDiscovery();

  Future<void> connect(String bikeId);

  /// Autenticação mútua + senha. Lança [FleetFailure] se a senha for recusada.
  Future<void> authenticate(String bikeId, String password);

  /// Modelo e funcionalidades. Não deve falhar a operação se a bike não
  /// responder a tudo.
  Future<FleetBikeDetails> identify(String bikeId);

  /// Envia a marcha e só retorna quando a bike confirmar o valor.
  Future<void> setGear(String bikeId, int level);

  /// Trava a bike e só retorna quando ela confirmar. Só é chamado se
  /// [identify] informou [BikeFeature.lock].
  Future<void> lock(String bikeId);

  /// Nunca deve lançar. Também cancela uma conexão ainda em andamento.
  Future<void> disconnect(String bikeId);
}
