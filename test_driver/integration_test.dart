import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart';

/// Driver for the integration tests, including the store-screenshot run.
///
/// Screenshots taken by `binding.takeScreenshot(name)` arrive here and are written to
/// `screenshots/<name>.png`, which is the path Codemagic collects as build artifacts.
Future<void> main() async {
  await _grantAndroidLocationPermissions();

  final Directory outputDir = Directory('screenshots');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final FlutterDriver driver = await FlutterDriver.connect();
  await integrationDriver(
    driver: driver,
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final File image = File(join(outputDir.path, '$name.png'));
      image.writeAsBytesSync(bytes);
      stdout.writeln('screenshot: ${image.path} (${bytes.length} bytes)');
      // Returning false would fail the test; we are capturing, not comparing.
      return true;
    },
  );
}

/// Pre-grants location to the Android build so the map does not open behind a permission
/// dialog and swallow the run.
///
/// Best-effort, and it must never break the iOS/macOS runs: the CI that produces the App Store
/// screenshots has no Android SDK at all, and the previous version of this file invoked `adb`
/// unconditionally via a hardcoded Windows path, throwing a ProcessException before the driver
/// ever connected.
Future<void> _grantAndroidLocationPermissions() async {
  final String? sdkRoot =
      Platform.environment['ANDROID_SDK_ROOT'] ?? Platform.environment['ANDROID_HOME'];
  if (sdkRoot == null) {
    stdout.writeln('No ANDROID_SDK_ROOT/ANDROID_HOME; skipping adb permission grants.');
    return;
  }

  final String adbPath = join(
    sdkRoot,
    'platform-tools',
    Platform.isWindows ? 'adb.exe' : 'adb',
  );
  if (!File(adbPath).existsSync()) {
    stdout.writeln('adb not found at $adbPath; skipping permission grants.');
    return;
  }

  const String package = 'au.com.bitbot.phonetowers.flutter';
  for (final String permission in <String>[
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
  ]) {
    try {
      final ProcessResult result =
          await Process.run(adbPath, <String>['shell', 'pm', 'grant', package, permission]);
      if (result.exitCode != 0) {
        // Already granted, or no device attached — neither is fatal.
        stdout.writeln('adb grant $permission exited ${result.exitCode}: ${result.stderr}');
      }
    } on ProcessException catch (e) {
      stdout.writeln('adb grant $permission failed: $e');
    }
  }
}
