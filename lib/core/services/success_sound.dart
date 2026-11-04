import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sons disponíveis para "operação concluída" (arquivos em assets/sounds/).
enum SuccessSoundOption {
  sino('sino', 'Sino'),
  marimba('marimba', 'Marimba'),
  tada('tada', 'Ta-dá'),
  pop('pop', 'Pop'),
  game('game', 'Game'),
  bloop('bloop', 'Bloop'),
  acorde('acorde', 'Acorde');

  const SuccessSoundOption(this.key, this.label);

  final String key;
  final String label;

  /// Caminho para o AudioPlayers (ele já prefixa `assets/`).
  String get asset => 'sounds/$key.wav';

  static bool isValid(String key) => values.any((o) => o.key == key);

  static SuccessSoundOption byKey(String key) =>
      values.firstWhere((o) => o.key == key, orElse: () => sino);
}

/// Toca o som de sucesso. Interface para poder trocar por um falso nos testes.
abstract interface class SuccessSound {
  Future<void> play(String key);
}

class AudioSuccessSound implements SuccessSound {
  final _player = AudioPlayer();

  @override
  Future<void> play(String key) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(SuccessSoundOption.byKey(key).asset));
    } catch (_) {
      // Sem áudio na plataforma / asset: silêncio, nunca quebra a operação.
    }
  }
}

final successSoundProvider = Provider<SuccessSound>(
  (ref) => AudioSuccessSound(),
);
