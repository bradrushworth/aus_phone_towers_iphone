import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/recent_searches.dart';

void main() {
  group('RecentSearches.withQuery', () {
    test('adds a new query to the front', () {
      expect(RecentSearches.withQuery(['a', 'b'], 'c'), ['c', 'a', 'b']);
    });

    test(
      're-using an existing query (exact case) moves it to the front, no duplicate',
      () {
        expect(RecentSearches.withQuery(['a', 'b', 'c'], 'b'), ['b', 'a', 'c']);
      },
    );

    test(
      're-using an existing query in a different case de-duplicates case-insensitively',
      () {
        expect(RecentSearches.withQuery(['dickson', 'a'], 'Dickson'), [
          'Dickson',
          'a',
        ]);
      },
    );

    test('trims whitespace and ignores a blank query', () {
      expect(RecentSearches.withQuery(['a'], '  b  '), ['b', 'a']);
      expect(RecentSearches.withQuery(['a', 'b'], '   '), ['a', 'b']);
    });

    test('caps the result at kMaxRecents', () {
      final existing = List<String>.generate(
        RecentSearches.kMaxRecents,
        (i) => 'q$i',
      );
      final result = RecentSearches.withQuery(existing, 'new');
      expect(result.length, RecentSearches.kMaxRecents);
      expect(result.first, 'new');
      expect(result.last, 'q${RecentSearches.kMaxRecents - 2}');
    });

    test('does not mutate the existing list', () {
      final existing = ['a', 'b'];
      RecentSearches.withQuery(existing, 'c');
      expect(existing, ['a', 'b']);
    });
  });

  group('RecentSearches.cleared', () {
    test('is empty', () {
      expect(RecentSearches.cleared(), isEmpty);
    });
  });

  group('RecentSearches.excluding', () {
    test('removes a case-insensitive match', () {
      expect(RecentSearches.excluding(['Dickson', 'Reid'], 'dickson'), [
        'Reid',
      ]);
    });

    test('leaves the list unchanged when there is no match', () {
      expect(RecentSearches.excluding(['Dickson', 'Reid'], 'Braddon'), [
        'Dickson',
        'Reid',
      ]);
    });

    test('handles an empty list', () {
      expect(RecentSearches.excluding([], 'anything'), isEmpty);
    });
  });
}
