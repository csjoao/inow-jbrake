import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/app_settings_local_datasource.dart';
import '../../domain/entities/app_settings.dart';

final appSettingsLocalProvider = Provider(
  (ref) => AppSettingsLocalDataSource(),
);

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  AppSettingsLocalDataSource get _local => ref.read(appSettingsLocalProvider);

  @override
  AppSettings build() => _local.load();

  Future<void> update(AppSettings next) async {
    state = next;
    await _local.save(next);
  }

  Future<void> resetToDefaults() async {
    await _local.clear();
    state = const AppSettings();
  }
}
