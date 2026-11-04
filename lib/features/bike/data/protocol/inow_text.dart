import 'dart:convert';

/// Notificação da bike como texto (`+CHAVE=valor`, `CODE_OK`…), ou `null`
/// se tiver bytes não imprimíveis (telemetria binária).
String? asInowText(List<int> bytes) {
  if (bytes.isEmpty) return null;
  for (final x in bytes) {
    final printable = (x >= 0x20 && x < 0x7F) || x == 0x0D || x == 0x0A;
    if (!printable) return null;
  }
  return ascii.decode(bytes);
}
