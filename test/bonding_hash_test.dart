import 'package:flutter_test/flutter_test.dart';
import 'package:inow_jbrake/features/bike/data/protocol/bonding_hash.dart';
import 'package:inow_jbrake/features/bike/data/protocol/inow_ble_profile.dart';

/// Vetores gerados rodando o `BleEncryption.java` original (descompilado).
void main() {
  const vectors = {
    InowBleProfile.standard: {
      '000000000000': 'c0fc7e7e',
      'A1B2C3D4E5F6': 'a09a58d8',
      'FFFFFFFFFFFF': '38fc807e',
      '123456789012': '967ad8b8',
      '0102030405060708': 'c0fa7878',
    },
    InowBleProfile.ln: {
      '000000000000': '3c36fcf4',
      'A1B2C3D4E5F6': 'c2b4185a',
      'FFFFFFFFFFFF': 'c23600f4',
      '123456789012': '927c16c6',
      '0102030405060708': '0234f8fa',
    },
    InowBleProfile.reel: {
      '000000000000': '0c3eea00',
      'A1B2C3D4E5F6': '22c4c41e',
      'FFFFFFFFFFFF': 'f23e1400',
      '123456789012': '027cb8c6',
      '0102030405060708': '0204e43e',
    },
  };

  vectors.forEach((profile, cases) {
    cases.forEach((nonce, expected) {
      test('${profile.name} $nonce -> $expected', () {
        expect(bondingHash(nonce, profile), expected);
      });
    });
  });
}
