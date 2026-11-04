import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(AppConstants.bikeBox);
  await Hive.openBox<dynamic>(AppConstants.appSettingsBox);
  await Hive.openBox<dynamic>(AppConstants.fleetBlocklistBox);

  runApp(const ProviderScope(child: InowJbrakeApp()));
}
