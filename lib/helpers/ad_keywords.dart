/// Ad keyword list for AdMob requests, mirroring the Android app's `MapsActivity.buildAdKeywords`
/// (head, then postcode, state and full state name, then suburb words from the site names).
/// Pure Dart so it is unit-tested without the ads SDK.
class AdKeywords {
  AdKeywords._();

  /// AdMob recommendation: keep the keyword list focused.
  static const int maxKeywords = 40;

  /// Always-on commercial terms, in the same order as Android. Keep it under ~24 entries so the
  /// site-derived terms below are not truncated away by the cap.
  static const List<String> head = [
    'mobile phone', 'mobile plan', 'SIM only', 'prepaid', 'unlimited data',
    'home internet', 'internet plan', 'NBN', 'broadband',
    'mobile coverage', 'coverage map', 'signal booster',
    'mobile tower', 'phone tower', 'cell tower',
    '5G', '4G', 'wireless internet',
    'GPS navigation', 'road trip', 'camping',
    'satellite phone', 'Australia',
  ];

  /// Common ACMA site-name filler words that are no use as ad keywords (Android's list).
  static const Set<String> stopWords = {
    'lot', 'site', 'exchange', 'road', 'rd', 'street', 'st', 'highway', 'hwy',
    'telstra', 'optus', 'vodafone', 'nbn',
  };

  static const Map<String, String> stateNames = {
    'NSW': 'New South Wales',
    'VIC': 'Victoria',
    'QLD': 'Queensland',
    'WA': 'Western Australia',
    'SA': 'South Australia',
    'TAS': 'Tasmania',
    'ACT': 'Australian Capital Territory',
    'NT': 'Northern Territory',
  };

  static final RegExp _separators = RegExp(r'[\s/&,]+');
  static final RegExp _letters = RegExp(r'^[A-Za-z]+$');

  static List<String> build(Iterable<({String? state, String? postcode, String? name})> sites) {
    final Set<String> keywords = <String>{...head};

    for (final site in sites) {
      if (keywords.length >= maxKeywords) break;
      final String? postcode = site.postcode;
      if (postcode != null && postcode.isNotEmpty) keywords.add(postcode);

      final String? state = site.state;
      if (state != null && state.isNotEmpty) {
        keywords.add(state);
        final String? full = stateNames[state];
        if (full != null) keywords.add(full);
      }

      final String? name = site.name;
      if (name != null && name.isNotEmpty) {
        for (final String token in name.split(_separators)) {
          if (token.length >= 3 &&
              _letters.hasMatch(token) &&
              !stopWords.contains(token.toLowerCase())) {
            keywords.add(token);
          }
        }
      }
    }

    final List<String> result = keywords.toList();
    return result.length > maxKeywords ? result.sublist(0, maxKeywords) : result;
  }
}
