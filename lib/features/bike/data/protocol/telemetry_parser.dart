/// Leitura dos pacotes binários que a bike envia sozinha.
///
/// Porta de `VehicleFragment`, `VehicleInfoActivity`, `SystemInfoActivity` e
/// `CycleInfoActivity` do app oficial. Velocidades e distâncias vêm × 10.
class Telemetry {
  const Telemetry({
    required this.format,
    this.battery,
    this.speed,
    this.trip,
    this.odo,
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

  /// Qual formato reconheceu o pacote (útil pra descobrir o da sua bike).
  final String format;
  final int? battery;

  /// km/h (ou mph, conforme a unidade configurada na bike).
  final double? speed;
  final double? trip;
  final double? odo;

  /// Tensão da bateria em volts.
  final double? voltage;

  /// Corrente em ampères.
  final double? current;
  final int? chargeCycles;
  final double? software;
  final double? firmware;

  /// Pedalada atual (CycleInfo): distância, velocidade máxima e tempo.
  final double? rideDistance;
  final double? rideTopSpeed;
  final int? rideSeconds;

  /// Totais acumulados (CycleInfo).
  final double? totalDistance;
  final int? totalSeconds;
}

int _u16(List<int> b, int i) => (b[i] << 8) | b[i + 1];
int _u16le(List<int> b, int i) => b[i] | (b[i + 1] << 8);
int _u24(List<int> b, int i) => (b[i] << 16) | (b[i + 1] << 8) | b[i + 2];
int _u32(List<int> b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
int _xor(List<int> b, int from, int toExclusive) {
  var x = 0;
  for (var i = from; i < toExclusive; i++) {
    x ^= b[i];
  }
  return x;
}

int _pct(int v) => v.clamp(0, 100);
double _tenth(int v) => v / 10.0;

/// Retorna `null` se o pacote não é de telemetria conhecida.
Telemetry? parseTelemetry(List<int> bytes) {
  final b = [for (final x in bytes) x & 0xFF];
  if (b.length < 9) return null;

  // Formato "LingDong 1.0": AA cmd .. .. .. .. .. .. xor BB
  if (b.length == 10 && b[0] == 0xAA && b[9] == 0xBB) {
    final checksumOk = _xor(b, 0, 8) == b[8];
    switch (b[1]) {
      case 0xA1 when checksumOk:
        return Telemetry(
          format: 'AA-A1',
          battery: _pct(b[3]),
          speed: _tenth(_u16(b, 4)),
        );
      case 0xA2 when checksumOk:
        return Telemetry(
          format: 'AA-A2',
          trip: _tenth(_u16(b, 3)),
          odo: _tenth(_u24(b, 5)),
        );
      case 0xA3:
        // Versões (SystemInfoActivity). O checksum desse é calculado de
        // outro jeito no original; aqui não é conferido.
        return Telemetry(
          format: 'AA-A3',
          software: _tenth(b[4]),
          firmware: _tenth(b[5]),
        );
    }
    return null;
  }

  // Pacotes ":" ... CR LF (dados da bateria e da pedalada).
  if (b[0] == 0x3A &&
      b[1] != 0xA0 &&
      b[b.length - 2] == 0x0D &&
      b[b.length - 1] == 0x0A) {
    final id = b[2];
    if (b[1] == 0x26 && id == 0x20 && b.length >= 13) {
      return Telemetry(
        format: ':26-20',
        rideTopSpeed: _tenth(_u16(b, 5)),
        rideDistance: _tenth(_u16(b, 7)),
        rideSeconds: _u16(b, 9),
      );
    }
    if (b[1] == 0x26 && id == 0x21 && b.length >= 14) {
      return Telemetry(
        format: ':26-21',
        totalDistance: _tenth(_u32(b, 4)),
        totalSeconds: _u32(b, 8),
      );
    }
    if (b.length >= 8) {
      switch (id) {
        case 9:
          return Telemetry(format: ':09', voltage: _u16le(b, 4) / 1000.0);
        case 23:
          return Telemetry(format: ':17', chargeCycles: _u16le(b, 4));
        case 82:
          return Telemetry(format: ':52', current: b[5] / 3.0);
      }
    }
    return null;
  }

  // Formato de 15 bytes: 01 0F .. bat .. .. trip(2) odo(4) speed(2) xor
  if (b.length == 15 &&
      b[0] == 0x01 &&
      b[1] == 0x0F &&
      _xor(b, 0, 14) == b[14]) {
    return Telemetry(
      format: '01-0F',
      battery: _pct(b[3]),
      trip: _tenth(_u16(b, 6)),
      odo: _tenth(_u32(b, 8)),
      speed: _tenth(_u16(b, 12)),
    );
  }

  // Formato de 14 bytes (huas03): 01 0B bat .. .. trip(2) odo(4) speed(2) ..
  if (b.length == 14 && b[0] == 0x01 && b[1] == 0x0B) {
    return Telemetry(
      format: '01-0B',
      battery: _pct(b[2]),
      trip: _tenth(_u16(b, 5)),
      odo: _tenth(_u32(b, 7)),
      speed: _tenth(_u16(b, 11)),
    );
  }

  // Formato ":" A0 (16 bytes): 3A A0 .. bat .. .. trip(2) odo(4) speed(2) ..
  // No original o byte 8 do ODO é deslocado 32 bits em int (vira no-op);
  // aqui usamos o que claramente era a intenção: 4 bytes big-endian.
  if (b.length >= 14 && b[1] == 0xA0) {
    return Telemetry(
      format: '3A-A0',
      battery: _pct(b[3]),
      trip: _tenth(_u16(b, 6)),
      odo: _tenth(_u32(b, 8)),
      speed: _tenth(_u16(b, 12)),
    );
  }

  return null;
}
