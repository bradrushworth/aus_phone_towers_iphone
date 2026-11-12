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
}
