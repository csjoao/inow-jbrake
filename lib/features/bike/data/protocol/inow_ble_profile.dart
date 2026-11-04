/// Perfis Bluetooth que o app oficial da INOW reconhece.
///
/// Extraído de `LFBluetootService` / `BleEncryption` do APK
/// `com.qmwheelbike.inow`. Cada perfil tem um serviço próprio, uma
/// característica de escrita, uma de leitura (notify) e uma chave/IV usados
/// na autenticação mútua (`+PM` / `+PA`).
enum InowBleProfile {
  /// CONNECT_TYPE 1 no app original.
  standard(
    service: '12ff69a0-73ae-11ee-b962-0002a5d5c51b',
    write: '12ff69a1-73ae-11ee-b962-0002a5d5c51b',
    notify: '12ff69a4-73ae-11ee-b962-0002a5d5c51b',
    keyHex: '3948D38E44E437F7242249F4A957874C',
    ivHex: '60C4EFFEA105F620E415AC8D7248031D',
  ),

  /// CONNECT_TYPE 2 ("LN").
  ln(
    service: 'd3b85480-7d79-464c-a646-0002a5d5c51b',
    write: 'd3b85481-7d79-464c-a646-0002a5d5c51b',
    notify: 'd3b85484-7d79-464c-a646-0002a5d5c51b',
    keyHex: '84AC42DD89E5D01FB639E6F3322C3375',
    ivHex: '2DDA7A3827869A8F31F747A4301C0935',
  ),

  /// CONNECT_TYPE 3 ("REEL").
  reel(
    service: '5e399c40-a7f1-11eb-bcbc-0002a5d5c51b',
    write: '5e399c41-a7f1-11eb-bcbc-0002a5d5c51b',
    notify: '5e399c44-a7f1-11eb-bcbc-0002a5d5c51b',
    keyHex: '1D6B4FE19817871B61E9DA3BAD51013B',
    ivHex: 'C47F6F9654C6181813DCE1628E8AE25D',
  );

  const InowBleProfile({
    required this.service,
    required this.write,
    required this.notify,
    required this.keyHex,
    required this.ivHex,
  });

  final String service;
  final String write;
  final String notify;
  final String keyHex;
  final String ivHex;

  static InowBleProfile? forService(String uuid) {
    final u = uuid.toLowerCase();
    for (final p in values) {
      if (p.service == u) return p;
    }
    return null;
  }
}
