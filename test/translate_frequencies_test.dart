import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';

void main() {
  group('TranslateFrequenciesTest', () {
    test('log2_256', () {
      expect(log2(256), closeTo(8, 0.001));
    });

    test('log2_50', () {
      expect(log2(50), closeTo(5.64385618977, 0.001));
    });

    test('formatFrequency12345Hz', () {
      expect(TranslateFrequencies.formatFrequency(12345, false), '12 kHz');
      expect(TranslateFrequencies.formatFrequency(12345, true), '12.3 kHz');
    });

    test('formatFrequency2142MHz', () {
      expect(
          TranslateFrequencies.formatFrequency(2142612345, false), '2143 MHz');
      expect(
          TranslateFrequencies.formatFrequency(2142612345, true), '2142.6 MHz');
    });

    test('formatFrequency26GHz', () {
      expect(
          TranslateFrequencies.formatFrequency(26123456789, false), '26 GHz');
      expect(
          TranslateFrequencies.formatFrequency(26123456789, true), '26.1 GHz');
    });

    test('convertLteRsrpToRssi', () {
      expect(TranslateFrequencies.convertLteRsrpToRssi(1400000), 18);
      expect(TranslateFrequencies.convertLteRsrpToRssi(3000000), 22);
      expect(TranslateFrequencies.convertLteRsrpToRssi(5000000), 24);
      expect(TranslateFrequencies.convertLteRsrpToRssi(10000000), 27);
      expect(TranslateFrequencies.convertLteRsrpToRssi(15000000), 29);
      expect(TranslateFrequencies.convertLteRsrpToRssi(20000000), 30);
      expect(TranslateFrequencies.convertLteRsrpToRssi(100000000), 30);
    });
  });
}
