import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Impede (ou volta a permitir) que a tela apague sozinha.
abstract interface class ScreenAwake {
  Future<void> set({required bool on});
}

class WakelockScreenAwake implements ScreenAwake {
  @override
  Future<void> set({required bool on}) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // Sem suporte na plataforma: a tela só apaga como de costume.
    }
  }
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => WakelockScreenAwake(),
);
