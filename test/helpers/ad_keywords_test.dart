import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/ad_keywords.dart';

typedef _S = ({String? state, String? postcode, String? name});

void main() {
  test('with no sites the list is exactly the head', () {
    expect(AdKeywords.build(const []), AdKeywords.head);
    expect(AdKeywords.head.first, 'mobile phone');
    expect(AdKeywords.head.length, 23);
  });

  test('head stays first and unchanged; postcode and state follow', () {
    final List<_S> sites = [(state: 'NSW', postcode: '2795', name: null)];
    final List<String> k = AdKeywords.build(sites);
    expect(k.sublist(0, AdKeywords.head.length), AdKeywords.head);
    expect(k.sublist(AdKeywords.head.length), ['2795', 'NSW', 'New South Wales']);
  });

  test('NSW adds New South Wales; an unknown state adds only itself', () {
    expect(AdKeywords.build([(state: 'NSW', postcode: null, name: null)]),
        containsAll(['NSW', 'New South Wales']));
    final List<String> k = AdKeywords.build([(state: 'XX', postcode: null, name: null)]);
    expect(k, contains('XX'));
    expect(k.length, AdKeywords.head.length + 1);
  });

  test('stop words, short and non-alphabetic tokens are dropped', () {
    final List<String> k = AdKeywords.build([
      (state: null, postcode: null, name: 'LOT 5 Telstra Exchange Gungahlin Rd/Hwy & Of 12ab'),
    ]);
    expect(k.sublist(AdKeywords.head.length), ['Gungahlin']);
  });

  test('duplicates are removed', () {
    final List<_S> sites = [
      (state: 'VIC', postcode: '3000', name: 'Melbourne'),
      (state: 'VIC', postcode: '3000', name: 'Melbourne'),
    ];
    final List<String> k = AdKeywords.build(sites);
    expect(k.toSet().length, k.length);
    expect(k.where((e) => e == 'Melbourne').length, 1);
  });

  test('the list is capped at 40', () {
    final List<_S> sites = [
      for (int i = 0; i < 100; i++) (state: null, postcode: '${2000 + i}', name: null),
    ];
    final List<String> k = AdKeywords.build(sites);
    expect(k.length, AdKeywords.maxKeywords);
    expect(k.sublist(0, AdKeywords.head.length), AdKeywords.head);
  });
}
