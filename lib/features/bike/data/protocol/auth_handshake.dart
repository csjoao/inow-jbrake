import 'dart:math';

import 'bonding_hash.dart';
import 'inow_ble_profile.dart';

/// Máquina de estados da autenticação mútua (`BleMutualAuthentication`).
///
/// Não fala com Bluetooth: recebe as mensagens de texto da bike em
/// [onMessage] e devolve o que deve ser enviado de volta.
///
/// Fluxo:
///   app  → `+VER?`
///   bike → `+VER=...`           app → `+PM?`
///   bike → `+PM>XXXXXXXXXXXX`   app → `+PM<hash(XXXXXXXXXXXX)`
///   bike → `+PM=OK`             app → `+PA<nonce`  (app passa a confiar)
///   bike → `+PA>hash(nonce)`    (app confere se a bike é legítima)
class AuthHandshake {
  AuthHandshake(this.profile, {Random? random}) : _random = random ?? Random();

  final InowBleProfile profile;
  final Random _random;

  /// A bike aceitou o hash do app (`+PM=OK`).
  bool trusted = false;

  /// A bike provou conhecer a mesma chave (`+PA>` correto).
  bool credible = false;

  /// A bike recusou o hash (`+PM=NK`).
  bool rejected = false;

  String? _expectedPaHash;

  String start() => '+VER?';

  /// Retorna a próxima mensagem a enviar, ou `null` se não há resposta.
  String? onMessage(String raw) {
    final msg = raw.trim().toUpperCase();

    if (!trusted && msg.length >= 6 && msg.startsWith('+PM')) {
      if (msg.length == 16 && msg[3] == '>') {
        return '+PM<${bondingHash(msg.substring(4), profile)}';
      }
      if (msg == '+PM=OK' || msg == '+PM>OK') {
        trusted = true;
        // O original concatena 6 números decimais aleatórios; a bike lê os
        // 12 primeiros caracteres como hex. Gerar 12 dígitos dá no mesmo.
        final code = List.generate(12, (_) => _random.nextInt(10)).join();
        _expectedPaHash = bondingHash(code, profile).toUpperCase();
        return '+PA<$code';
      }
      if (msg == '+PM=NK') rejected = true;
      return null;
    }

    if (!credible && msg.length == 12 && msg.startsWith('+PA>')) {
      credible = msg.substring(4) == _expectedPaHash;
      return null;
    }

    if (msg.length > 8 && msg.startsWith('+VER=')) return '+PM?';
    return null;
  }
}
