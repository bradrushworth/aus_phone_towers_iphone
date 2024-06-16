import 'dart:async';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart';
import 'package:flutter_driver/flutter_driver.dart';

//Future<void> main() => integrationDriver();

Future<void> main() async {
  final Map<String, String> envVars = Platform.environment;
  String adbPath = join(
    envVars['ANDROID_SDK_ROOT'] ??
        envVars['ANDROID_HOME'] ??
        'C:\\Users\\Brad\\AppData\\Local\\Android\\Sdk',
    'platform-tools',
    Platform.isWindows ? 'adb.exe' : 'adb',
  );
  print('adbPath=${adbPath}');
  await Process.run(adbPath, [
    'shell',
    'pm',
    'grant',
    'au.com.bitbot.phonetowers.flutter',
    'android.permission.ACCESS_FINE_LOCATION'
  ]);
  await Process.run(adbPath, [
    'shell',
    'pm',
    'grant',
    'au.com.bitbot.phonetowers.flutter',
    'android.permission.ACCESS_COARSE_LOCATION'
  ]);

  final FlutterDriver driver = await FlutterDriver.connect();
  await integrationDriver(
    driver: driver,
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final File image = File('$screenshotName.png');
      image.writeAsBytesSync(screenshotBytes);
      // Return false if the screenshot is invalid.
      return true;
    },
  );
}

// import'package:integration_test/integration_test_driver.dart';
//
// Future<void> main() => integrationDriver();
