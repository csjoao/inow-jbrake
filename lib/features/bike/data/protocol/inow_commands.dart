/// Comandos de texto aceitos pela bike (extraídos do app oficial).
///
/// Para ler o valor atual, envie `+CHAVE=?`; a bike responde `+CHAVE=valor`.
abstract final class InowCommands {
  static String password(String pwd) => 'CODE=$pwd';
  static const deviceId = 'GETDEVID';

  static String mode(int level) => '+MODE=$level';
  static const modeQuery = '+MODE=?';
  static const maxModeQuery = '+MDMX=?';

  static String lock({required bool locked}) => '+LOCK=${locked ? 1 : 0}';
  static const lockQuery = '+LOCK=?';

  /// Farol (sem o "+" no original).
  static String headlight({required bool on}) => 'HLGT=${on ? 1 : 0}';
  static const headlightQuery = 'HLGT=?';

  static const unitQuery = '+UNIT=?';

  /// Velocidade máxima em km/h: `+SPLT=0XX`.
  static String maxSpeed(int kmh) =>
      '+SPLT=0${kmh.clamp(0, 99).toString().padLeft(2, '0')}';
  static const maxSpeedQuery = '+SPLT=?';

  /// Desligamento automático em minutos: `+STBY=NN`.
  static String standby(int minutes) =>
      '+STBY=${minutes.toString().padLeft(2, '0')}';
  static const standbyQuery = '+STBY=?';

  /// Senha da trava (`ChangeLockPwdActivity`).
  static String lockPassword(String pwd) => '+LKSC=$pwd';

  /// Senha de marcha, 4 dígitos (`ChangeGearPwdActivity`).
  static String gearPassword(String pwd) => '+FCPWMD=$pwd';
  static const gearPasswordQuery = '+FCPWRD=?';

  /// Nome e senha (6 dígitos) do Bluetooth (`ChangeBleInfoActivity`).
  static String bleName(String name) => 'SN+$name';
  static String blePassword(String pwd) => 'SC+$pwd';

  /// Cartões NFC (`NfcActivity`).
  static const nfcStartPairing = '+RFAD=1';
  static const nfcStopPairing = '+RFAD=0';
  static const nfcList = '+RFRP=?';
  static String nfcDelete(String cardId) => '+RFDL=$cardId';
}

/// Ajuste de múltipla escolha (envia `+CHAVE=valor`).
///
/// Os rótulos são palpites a partir dos nomes das telas do app oficial
/// (BrakeForceActivity, CruiseSettingActivity, ...). Confira na bike.
class InowSetting {
  const InowSetting(this.key, this.title, this.options, {this.customQuery});

  /// Ex.: `BRAKE` → envia `+BRAKE=2`, consulta com `+BRAKE=?`.
  final String key;
  final String title;

  /// valor enviado → rótulo exibido.
  final Map<String, String> options;

  /// Consulta fora do padrão `+CHAVE=?` (ex.: `+LUMA=M0L?`).
  final String? customQuery;

  String set(String value) => '+$key=$value';
  String get query => customQuery ?? '+$key=?';
}

const _levels0to5 = {
  '0': '0',
  '1': '1',
  '2': '2',
  '3': '3',
  '4': '4',
  '5': '5',
};

const ridingSettings = <InowSetting>[
  InowSetting('MPMD', 'Modo de potência', {'0': 'Eco', '1': 'Sport'}),
  InowSetting('ZSST', 'Partida do zero', {'0': 'Desligado', '1': 'Ligado'}),
  InowSetting('CRZE', 'Cruise control', {'0': 'Desligado', '1': 'Ligado'}),
  InowSetting('HANDRAIL', 'Força de arranque do acelerador', {
    '1': '1',
    '2': '2',
    '3': '3',
    '4': '4',
    '5': '5',
  }),
  InowSetting('BRAKE', 'Força do freio', _levels0to5),
  InowSetting('DRIVMD', 'Modo de tração', {'0': '0', '1': '1'}),
  InowSetting('GEARMODE', 'Modo de marcha', {'0': '0', '1': '1'}),
];

const speedSettings = <InowSetting>[
  InowSetting('SPDLMT', 'Limite de velocidade', {
    '0': 'Desligado',
    '1': 'Ligado',
  }),
];

const displaySettings = <InowSetting>[
  InowSetting('UNIT', 'Unidade', {'0': 'km', '1': 'milhas'}),
  InowSetting('LUMA', 'Brilho do painel', {
    'M0L0': 'Baixo',
    'M0L1': 'Médio',
    'M0L2': 'Alto',
  }, customQuery: '+LUMA=M0L?'),
  InowSetting('TIM', 'Tempo da luz', {
    'L3': '3',
    'L5': '5',
    'L7': '7',
  }, customQuery: '+TIM=L?'),
];

const allChoiceSettings = [
  ...ridingSettings,
  ...speedSettings,
  ...displaySettings,
];
