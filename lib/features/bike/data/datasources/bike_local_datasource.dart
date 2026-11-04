import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';

/// Guarda no aparelho a senha de cada bike e a última bike usada
/// (base para a conexão automática que virá depois).
class BikeLocalDataSource {
  Box<dynamic> get _box => Hive.box<dynamic>(AppConstants.bikeBox);

  String? passwordFor(String deviceId) => _box.get('pwd:$deviceId') as String?;

  Future<void> savePassword(String deviceId, String pwd) =>
      _box.put('pwd:$deviceId', pwd);

  Future<void> removePassword(String deviceId) => _box.delete('pwd:$deviceId');

  ({String id, String name})? get lastBike {
    final id = _box.get('last:id') as String?;
    if (id == null) return null;
    return (id: id, name: (_box.get('last:name') as String?) ?? id);
  }

  Future<void> saveLastBike(String id, String name) async {
    await _box.put('last:id', id);
    await _box.put('last:name', name);
  }

  Future<void> forgetLastBike() async {
    final id = _box.get('last:id') as String?;
    if (id != null) await removePassword(id);
    await _box.delete('last:id');
    await _box.delete('last:name');
  }
}
