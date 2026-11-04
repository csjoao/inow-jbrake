import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inow_jbrake/features/bike/data/protocol/auth_handshake.dart';
import 'package:inow_jbrake/features/bike/data/protocol/bonding_hash.dart';
import 'package:inow_jbrake/features/bike/data/protocol/inow_ble_profile.dart';
import 'package:inow_jbrake/features/bike/data/protocol/inow_commands.dart';
import 'package:inow_jbrake/features/bike/data/protocol/telemetry_parser.dart';

void main() {
  group('AuthHandshake', () {
    test('fluxo completo VER → PM → PA', () {
      final auth = AuthHandshake(InowBleProfile.standard, random: Random(1));
      expect(auth.start(), '+VER?');
      expect(auth.onMessage('+VER=1.2.3.4'), '+PM?');
      expect(auth.onMessage('+PM>A1B2C3D4E5F6'), '+PM<a09a58d8');
      expect(auth.trusted, isFalse);

      final pa = auth.onMessage('+PM=OK')!;
      expect(auth.trusted, isTrue);
      expect(pa, startsWith('+PA<'));
      final code = pa.substring(4);
      expect(code, hasLength(12));

      final bikeAnswer = bondingHash(
        code,
        InowBleProfile.standard,
      ).toUpperCase();
      expect(auth.onMessage('+PA>$bikeAnswer'), isNull);
      expect(auth.credible, isTrue);
    });

    test('PA errado não é confiável', () {
      final auth = AuthHandshake(InowBleProfile.standard)..onMessage('+PM=OK');
      auth.onMessage('+PA>00000000');
      expect(auth.credible, isFalse);
    });

    test('PM=NK marca recusa', () {
      final auth = AuthHandshake(InowBleProfile.standard)..onMessage('+PM=NK');
      expect(auth.rejected, isTrue);
      expect(auth.trusted, isFalse);
    });
  });

  group('parseTelemetry', () {
    int xor(List<int> b) => b.fold(0, (a, x) => a ^ x);

    test('formato AA-A1 (bateria + velocidade)', () {
      final body = [0xAA, 0xA1, 0x00, 51, 0x00, 0xFA, 0x00, 0x00];
      final t = parseTelemetry([...body, xor(body), 0xBB])!;
      expect(t.format, 'AA-A1');
      expect(t.battery, 51);
      expect(t.speed, 25.0);
    });

    test('formato AA-A2 (viagem + ODO)', () {
      // trip 43 (4.3 km), odo 4683 (468.3 km)
      final body = [0xAA, 0xA2, 0x00, 0x00, 43, 0x00, 0x12, 0x4B];
      final t = parseTelemetry([...body, xor(body), 0xBB])!;
      expect(t.trip, 4.3);
      expect(t.odo, 468.3);
    });

    test('formato AA com checksum errado é ignorado', () {
      final body = [0xAA, 0xA1, 0x00, 51, 0x00, 0xFA, 0x00, 0x00];
      expect(parseTelemetry([...body, xor(body) ^ 1, 0xBB]), isNull);
    });

    test('formato 01-0F (15 bytes)', () {
      final body = [
        0x01, 0x0F, 0x00, 80, 0x00, 0x00, //
        0x00, 43, // trip
        0x00, 0x00, 0x12, 0x4B, // odo
        0x00, 0x96, // speed 15.0
      ];
      final t = parseTelemetry([...body, xor(body)])!;
      expect(t.format, '01-0F');
      expect(t.battery, 80);
      expect(t.trip, 4.3);
      expect(t.odo, 468.3);
      expect(t.speed, 15.0);
    });

    test('formato 3A-A0 (16 bytes)', () {
      final p = [
        0x3A, 0xA0, 0x00, 51, 0x00, 0x00, //
        0x00, 43, 0x00, 0x00, 0x12, 0x4B, 0x00, 0x00, 0x00, 0x00,
      ];
      final t = parseTelemetry(p)!;
      expect(t.format, '3A-A0');
      expect(t.battery, 51);
      expect(t.odo, 468.3);
      expect(t.speed, 0);
    });

    test('texto não é telemetria', () {
      expect(parseTelemetry('CODE_OK'.codeUnits), isNull);
    });
  });

  group('pacotes de informação', () {
    test('tensão (:09, little-endian, mV)', () {
      // 0x9C40 = 40000 mV = 40.0 V
      final t = parseTelemetry([
        0x3A,
        0x16,
        9,
        0x00,
        0x40,
        0x9C,
        0x00,
        0x00,
        0x0D,
        0x0A,
      ])!;
      expect(t.voltage, 40.0);
    });

    test('ciclos de carga (:17)', () {
      final t = parseTelemetry([
        0x3A,
        0x16,
        23,
        0x00,
        0x2A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x0A,
      ])!;
      expect(t.chargeCycles, 42);
    });

    test('corrente (:52, byte 5 / 3)', () {
      final t = parseTelemetry([
        0x3A,
        0x16,
        82,
        0x00,
        0x00,
        30,
        0x00,
        0x00,
        0x0D,
        0x0A,
      ])!;
      expect(t.current, 10.0);
    });

    test('pedalada atual (:26 20)', () {
      final t = parseTelemetry([
        0x3A, 0x26, 0x20, 0x00, 0x00, //
        0x01, 0x2C, // top 30.0
        0x00, 43, // distância 4.3
        0x0E, 0x10, // 3600 s
        0x0D, 0x0A,
      ])!;
      expect(t.rideTopSpeed, 30.0);
      expect(t.rideDistance, 4.3);
      expect(t.rideSeconds, 3600);
    });

    test('totais (:26 21)', () {
      final t = parseTelemetry([
        0x3A, 0x26, 0x21, 0x00, //
        0x00, 0x00, 0x12, 0x4B, // 468.3 km
        0x00, 0x00, 0x1C, 0x20, // 7200 s
        0x0D, 0x0A,
      ])!;
      expect(t.totalDistance, 468.3);
      expect(t.totalSeconds, 7200);
    });

    test('versões (AA A3)', () {
      final t = parseTelemetry([0xAA, 0xA3, 0, 0, 12, 21, 0, 0, 0, 0xBB])!;
      expect(t.software, 1.2);
      expect(t.firmware, 2.1);
    });
  });

  group('InowCommands', () {
    test('formatos de texto iguais ao original', () {
      expect(InowCommands.maxSpeed(25), '+SPLT=025');
      expect(InowCommands.maxSpeed(5), '+SPLT=005');
      expect(InowCommands.standby(5), '+STBY=05');
      expect(InowCommands.standby(15), '+STBY=15');
      expect(InowCommands.headlight(on: true), 'HLGT=1');
      expect(InowCommands.blePassword('123456'), 'SC+123456');
      expect(InowCommands.bleName('JBRAKE'), 'SN+JBRAKE');
      expect(InowCommands.gearPassword('1234'), '+FCPWMD=1234');
    });
  });
}
