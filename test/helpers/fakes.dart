import 'package:inow_jbrake/core/services/screen_awake.dart';
import 'package:inow_jbrake/features/app_settings/data/datasources/app_settings_local_datasource.dart';
import 'package:inow_jbrake/features/app_settings/domain/entities/app_settings.dart';
import 'package:inow_jbrake/features/bike/data/datasources/bike_local_datasource.dart';
import 'package:inow_jbrake/features/fleet/data/datasources/fleet_blocklist_local_datasource.dart';

/// Substitutos em memória do que o app guarda no Hive / pede ao sistema.

class MemorySettings extends AppSettingsLocalDataSource {
  MemorySettings([this.value = const AppSettings()]);
  AppSettings value;

  @override
  AppSettings load() => value;

  @override
  Future<void> save(AppSettings s) async => value = s;
}

class MemoryBlocklist extends FleetBlocklistLocalDataSource {
  final saved = <String, String>{};

  @override
  Map<String, String> load() => {...saved};

  @override
  Future<void> add(String id, String name) async => saved[id] = name;

  @override
  Future<void> remove(String id) async => saved.remove(id);
}

/// Nenhuma bike salva na aba Veículo.
class NoBikeLocal extends BikeLocalDataSource {
  @override
  ({String id, String name})? get lastBike => null;
}

/// Registra os pedidos de manter a tela ligada.
class FakeScreenAwake implements ScreenAwake {
  final calls = <bool>[];

  @override
  Future<void> set({required bool on}) async => calls.add(on);
}
