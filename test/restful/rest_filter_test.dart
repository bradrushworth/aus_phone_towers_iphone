import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/restful/rest_filter.dart';

/// Mirrors the Java app's RestFilterTest: RESTify faults an empty `_filter`
/// VALUE (`model==`) with HTTP 412 ERROR #120, so blank/null values must be
/// rejected before a request is built.
void main() {
  group('RestFilter.isUsableValue', () {
    test('rejects null', () {
      expect(RestFilter.isUsableValue(null), isFalse);
    });

    test('rejects empty string', () {
      expect(RestFilter.isUsableValue(''), isFalse);
    });

    test('rejects whitespace-only strings', () {
      expect(RestFilter.isUsableValue(' '), isFalse);
      expect(RestFilter.isUsableValue('\t\n  '), isFalse);
    });

    test('accepts real values', () {
      expect(RestFilter.isUsableValue('Pixel 8 Pro'), isTrue);
      expect(RestFilter.isUsableValue('r3dp'), isTrue);
      expect(RestFilter.isUsableValue('0'), isTrue);
    });

    test('accepts values with surrounding whitespace', () {
      // Trimmed only for the emptiness check — a padded but non-blank value is
      // still usable (the caller decides how to encode it).
      expect(RestFilter.isUsableValue(' abc '), isTrue);
    });
  });
}
