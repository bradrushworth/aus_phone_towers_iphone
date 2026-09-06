import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/carrier_tint.dart';
import 'package:phonetowers/helpers/telco_helper.dart';

/// Pins the contrast of every CarrierTint role against WCAG 2 thresholds, for every colour
/// TelcoHelper.getColor can return plus CarrierTint.neutral, in both themes. Mirrors the Android
/// app's CarrierTintTest; the mix weights were chosen by measuring exactly these ratios, so a
/// change that drops a pair below 4.5:1 (or the large bold carrier name below 3:1) fails here
/// rather than on a phone in the sun.
void main() {
  const Color lightSurface = Color(0xFFFFFBFE); // M3 baseline light surface
  const Color darkSurface = CarrierTint.darkSurface;
  const Color telstra = Color(0xFF0D54FF);
  const Color white = Color(0xFFFFFFFF);

  // The real table, not literals: the Java test has to hard-code its seeds because
  // android.graphics.Color is unmocked there; this one can read TelcoHelper directly. Includes
  // the broadcast rose, which deepened to #E8639B in the same release and now clears every
  // threshold (the pale #FFB1D8 failed all four on the light theme).
  final Map<String, Color> seeds = <String, Color>{
    for (final Telco telco in Telco.values)
      if (TelcoHelper.isTelecommunications(telco))
        TelcoHelper.getName(telco): TelcoHelper.getColor(telco, 255),
    'Broadcast rose': TelcoHelper.getColor(Telco.Radio, 255),
    'Neutral': CarrierTint.neutral,
  };

  void assertAtLeast(String what, double threshold, double ratio) {
    expect(ratio, greaterThanOrEqualTo(threshold),
        reason: '$what is ${ratio.toStringAsFixed(2)}:1, below $threshold:1');
  }

  void assertRoles(String label, CarrierTint t, Color surface) {
    assertAtLeast('$label chip text on chip', 4.5, CarrierTint.contrast(t.chipFg, t.chipBg));
    assertAtLeast('$label pill text on pill', 4.5, CarrierTint.contrast(t.pillFg, t.pillBg));
    assertAtLeast('$label link on surface', 4.5, CarrierTint.contrast(t.accent, surface));
    // Large bold text: 3:1 is the WCAG AA floor.
    assertAtLeast('$label carrier name on surface', 3.0, CarrierTint.contrast(t.name, surface));
    // Segment labels pick white or the dark surface per segment; Vodafone's dark segA is the
    // tight one at 4.3:1 either way, hence 3:1 for a decorative bar whose figures repeat in text.
    assertAtLeast('$label label on segment A', 3.0, CarrierTint.contrast(t.onSegA, t.segA));
    assertAtLeast('$label label on segment B', 3.0, CarrierTint.contrast(t.onSegB, t.segB));
  }

  test('seeds cover the six carriers, the rose and the neutral', () {
    expect(seeds.length, 8, reason: seeds.keys.join(', '));
  });

  test('every colour meets the thresholds on the light surface', () {
    seeds.forEach((String name, Color seed) {
      assertRoles('$name light', CarrierTint.of(seed, dark: false), lightSurface);
    });
  });

  test('every colour meets the thresholds on the dark surface', () {
    seeds.forEach((String name, Color seed) {
      assertRoles('$name dark', CarrierTint.of(seed, dark: true), darkSurface);
    });
  });

  test('segment labels pick the darker ink on a wash', () {
    // Light theme: segment A is the carrier darkened, segment B a wash toward white.
    final CarrierTint light = CarrierTint.of(telstra, dark: false);
    expect(light.onSegA, white);
    expect(light.onSegB, CarrierTint.darkSurface);
    // Dark theme: segment B is the carrier sunk toward the surface, so white goes there.
    final CarrierTint dark = CarrierTint.of(telstra, dark: true);
    expect(dark.onSegB, white);
    expect(CarrierTint.luminance(white), closeTo(1.0, 1e-9));
    expect(CarrierTint.luminance(const Color(0xFF000000)), closeTo(0.0, 1e-9));
  });

  test('the Telstra name is legible on the dark sheet where the raw blue was not', () {
    final double raw = CarrierTint.contrast(telstra, darkSurface);
    final double tinted =
        CarrierTint.contrast(CarrierTint.of(telstra, dark: true).name, darkSurface);
    expect(raw, lessThan(3.5), reason: 'raw Telstra blue on the dark surface');
    assertAtLeast('tinted Telstra name on the dark surface', 6.0, tinted);
  });

  test('mix endpoints and midpoint match the Java implementation', () {
    expect(CarrierTint.mix(telstra, white, 0), telstra);
    expect(CarrierTint.mix(telstra, white, 1), white);
    // Per channel: 0x0D->0x86 (13 + 242 * .5 = 134), 0x54->0xAA (84 + 171 * .5 = 169.5 -> 170),
    // 0xFF stays 0xFF.
    expect(CarrierTint.mix(telstra, white, 0.5), const Color(0xFF86AAFF));
    expect(CarrierTint.mix(const Color(0xFF000000), white, 0.5), const Color(0xFF808080));
  });

  test('mix and every role are opaque whatever the input alpha', () {
    expect(
        CarrierTint.mix(const Color(0x00000000), const Color(0x00000000), 0.5).toARGB32() &
            0xFF000000,
        0xFF000000);
    for (final bool dark in <bool>[false, true]) {
      // TelcoHelper.getColor(alpha) can hand over a translucent polygon colour; chrome is opaque.
      final CarrierTint t = CarrierTint.of(const Color(0x400D54FF), dark: dark);
      for (final Color role in <Color>[
        t.name,
        t.chipBg,
        t.chipFg,
        t.pillBg,
        t.pillFg,
        t.accent,
        t.segA,
        t.segB,
      ]) {
        expect(role.toARGB32() & 0xFF000000, 0xFF000000);
      }
    }
  });

  test('the neutral is the icon night blue', () {
    expect(CarrierTint.neutral, const Color(0xFF34406B));
  });
}
