import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/networking/response/site_response.dart';

void main() {
  group('SearchHelper.searchFailed (iPhone audit I8)', () {
    test('a null response is a failed request, not zero rows', () {
      expect(SearchHelper.searchFailed(null), isTrue);
    });

    test('an empty but present response is a real answer', () {
      expect(SearchHelper.searchFailed(SiteResponse()), isFalse);
    });
  });

  group('SearchHelper.buildFilter (iPhone audit I16)', () {
    test('a four-digit query is a postcode filter', () {
      expect(SearchHelper.buildFilter('2600'), 'postcode~~2600');
    });

    test('surrounding spaces do not stop a postcode match', () {
      expect(SearchHelper.buildFilter('  2600 '), 'postcode~~2600');
    });

    test('four digits inside a longer query are a name filter', () {
      expect(SearchHelper.buildFilter('Lot 1234 Smith Rd'),
          'name~~%25Lot%201234%20Smith%20Rd%25');
    });

    test('a name query keeps the wildcard format', () {
      expect(SearchHelper.buildFilter('Northbourne'),
          'name~~%25Northbourne%25');
    });
  });
}
