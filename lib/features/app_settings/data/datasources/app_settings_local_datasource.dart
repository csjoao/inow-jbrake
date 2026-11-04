import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/app_settings.dart';

/// Guarda as configurações da aplicação no aparelho (caixa própria,
/// separada dos dados da bike).
class AppSettingsLocalDataSource {
  Box<dynamic> get _box => Hive.box<dynamic>(AppConstants.appSettingsBox);

  AppSettings load() => AppSettings.fromMap(_box.toMap());

  Future<void> save(AppSettings s) => _box.putAll(s.toMap());

  Future<void> clear() => _box.clear();
}
