import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/problem_report_helper.dart';

void main() {
  group('ProblemReportHelper.buildSubject', () {
    test('all fields present', () {
      final String subject = ProblemReportHelper.buildSubject(
        model: 'Pixel 8 Pro',
        deviceId: '025fd90d7bceaab7',
        version: '7.7.48',
        buildNumber: '331',
      );
      expect(subject,
          'Aus Phone Towers Problem Report: Pixel 8 Pro, 025fd90d7bceaab7, v7.7.48+331');
    });

    test('missing device id', () {
      final String subject = ProblemReportHelper.buildSubject(
        model: 'iPhone15,2',
        deviceId: null,
        version: '1.14.9',
        buildNumber: '144',
      );
      expect(subject, 'Aus Phone Towers Problem Report: iPhone15,2, v1.14.9+144');
    });

    test('missing model', () {
      final String subject = ProblemReportHelper.buildSubject(
        model: null,
        deviceId: 'ABC-123',
        version: '1.14.9',
        buildNumber: '144',
      );
      expect(subject, 'Aus Phone Towers Problem Report: ABC-123, v1.14.9+144');
    });

    test('missing version omits the v-part entirely (no stray "vnull")', () {
      final String subject = ProblemReportHelper.buildSubject(
        model: 'Pixel 8 Pro',
        deviceId: '025fd90d7bceaab7',
        version: null,
        buildNumber: '331',
      );
      expect(subject, 'Aus Phone Towers Problem Report: Pixel 8 Pro, 025fd90d7bceaab7');
    });

    test('missing build number falls back to just v<version>', () {
      final String subject = ProblemReportHelper.buildSubject(
        model: 'Pixel 8 Pro',
        deviceId: '025fd90d7bceaab7',
        version: '7.7.48',
        buildNumber: null,
      );
      expect(subject, 'Aus Phone Towers Problem Report: Pixel 8 Pro, 025fd90d7bceaab7, v7.7.48');
    });

    test('all fields missing falls back to the bare prefix, no stray punctuation', () {
      final String subject = ProblemReportHelper.buildSubject();
      expect(subject, 'Aus Phone Towers Problem Report');
    });

    test('blank strings are treated the same as missing', () {
      final String subject = ProblemReportHelper.buildSubject(
        model: '  ',
        deviceId: '',
        version: '7.7.48',
        buildNumber: '331',
      );
      expect(subject, 'Aus Phone Towers Problem Report: v7.7.48+331');
    });

    test('only device id present', () {
      final String subject = ProblemReportHelper.buildSubject(deviceId: '025fd90d7bceaab7');
      expect(subject, 'Aus Phone Towers Problem Report: 025fd90d7bceaab7');
    });
  });
}
