import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/telco_helper.dart';

/// Pins the carrier colour table the two apps share. The Android app's Telco.getHtmlColour and
/// Telco.getColor carry the same table and its TelcoColourTest holds the same literals: change
/// one, change all four (both tables, both tests).
void main() {
  /// One rose for every licence type that is not a mobile carrier. Deepened from #FFB1D8 on
  /// 2026-09-06 because PolygonHelper fills a non-carrier polygon at 20% opacity, and at that
  /// opacity the pale rose could not be told from the light basemap.
  const Color broadcastRose = Color(0xFFE8639B);

  const Map<Telco, Color> carriers = {
    Telco.Telstra: Color(0xFF0D54FF),
    Telco.Optus: Color(0xFF007F87),
    Telco.Vodafone: Color(0xFFE60000),
    Telco.Dense_Air: Color(0xFF11354F),
    Telco.NBN: Color(0xFF910F91),
    Telco.Other: Color(0xFF007FFF),
  };

  test('carrier colours match the shared table', () {
    carriers.forEach((Telco telco, Color expected) {
      expect(TelcoHelper.getColor(telco, 255), expected, reason: telco.name);
    });
  });

  test('every broadcast type shares the deeper rose', () {
    final List<Telco> broadcast =
        Telco.values.where((Telco t) => !carriers.containsKey(t)).toList();
    expect(broadcast, containsAll([Telco.Radio, Telco.TV, Telco.CBRS, Telco.Aviation, Telco.Civil, Telco.Pager]));
    for (final Telco telco in broadcast) {
      expect(TelcoHelper.getColor(telco, 255), broadcastRose, reason: telco.name);
    }
  });

  test('no two carriers share a colour and none borrows the rose', () {
    final Set<Color> seen = carriers.keys.map((Telco t) => TelcoHelper.getColor(t, 255)).toSet();
    expect(seen.length, carriers.length);
    expect(seen, isNot(contains(broadcastRose)));
  });

  test('alpha is applied as given', () {
    expect(TelcoHelper.getColor(Telco.Radio, 50), const Color(0x32E8639B));
  });
}
