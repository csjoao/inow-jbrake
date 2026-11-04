import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('docs/screenshots/$name.png');
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
