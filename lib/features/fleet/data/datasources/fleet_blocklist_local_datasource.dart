import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';

/// Bikes que a operação deve pular, salvas no aparelho (id → nome).
class FleetBlocklistLocalDataSource {
  Box<dynamic> get _box => Hive.box<dynamic>(AppConstants.fleetBlocklistBox);

  Map<String, String> load() => {
    for (final e in _box.toMap().entries)
      if (e.key is String && e.value is String)
        e.key as String: e.value as String,
  };

  Future<void> add(String id, String name) => _box.put(id, name);

  Future<void> remove(String id) => _box.delete(id);
}
