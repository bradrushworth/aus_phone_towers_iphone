import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/export_helper.dart';

void main() {
  group('ExportHelper.isExpired', () {
    final DateTime now = DateTime(2026, 11, 12, 12);

    test('keeps an export written today', () {
      expect(ExportHelper.isExpired(now, now), isFalse);
    });

    test('keeps an export exactly 30 days old', () {
      expect(ExportHelper.isExpired(now.subtract(const Duration(days: 30)), now), isFalse);
    });

    test('deletes an export more than 30 days old', () {
      expect(
          ExportHelper.isExpired(
              now.subtract(const Duration(days: 30, minutes: 1)), now),
          isTrue);
    });
  });

  group('ExportHelper.describeSavedFiles', () {
    const List<String> paths = <String>[
      '/var/mobile/Containers/Data/Application/ABC/Documents/Exports/AusPhoneTowers_Towers_20261112_120000.geojson',
      '/var/mobile/Containers/Data/Application/ABC/Documents/Exports/AusPhoneTowers_Towers_20261112_120000.csv',
    ];

    test('on iPhone names the Files location and lists file names only', () {
      final String message = ExportHelper.describeSavedFiles(paths, isIOS: true);
      expect(message, startsWith(
          'Saved to Files → On My iPhone → Aus Phone Towers → Exports:'));
      expect(message, contains('AusPhoneTowers_Towers_20261112_120000.geojson'));
      expect(message, contains('AusPhoneTowers_Towers_20261112_120000.csv'));
      expect(message.contains('/var/mobile'), isFalse);
    });

    test('elsewhere names the Exports folder and lists file names only', () {
      final String message = ExportHelper.describeSavedFiles(paths, isIOS: false);
      expect(message, startsWith("Saved to the app's Exports folder:"));
      expect(message.contains('/'), isFalse);
    });
  });

  test('keeps the Exports folder name stable', () {
    expect(ExportHelper.kExportsFolderName, 'Exports');
    expect(ExportHelper.kExportRetention, const Duration(days: 30));
  });
}
