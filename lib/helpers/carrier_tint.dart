import 'dart:math' as math;
import 'dart:ui' show Color;

/// Colour roles derived from a carrier's identity colour, for chrome that belongs to one
/// carrier: here the carrier chip on a site's details sheet; in the Android app the whole
/// connection card.
///
/// The roles are tonal: a wash of the carrier colour with dark text on the light surface and
/// light text on the dark one, never a solid block. A solid carrier fill was tried in the
/// Android app and rejected: next to the solid signal chip, Vodafone red and weak-signal red
/// read as one alarm, and Telstra blue next to a strong-signal green looked like a second
/// status rather than a name. Drawing the carrier name in the raw colour was the previous
/// state here, and it put Telstra blue at 3.0:1 on the dark sheet; its tinted name is 6.2:1.
///
/// A port of the Android app's CarrierTint (utilities/CarrierTint.java) with the same mix
/// weights, so the two apps tint identically. The Java side blends in float arithmetic and this
/// side in double, so a channel can differ by one step in 255 where a product lands on a half;
/// nothing visible. Every pair is pinned against WCAG 2 thresholds in
/// test/helpers/carrier_tint_test.dart for every colour TelcoHelper.getColor can return plus
/// [neutral], in both themes.
///
/// The signal ramp, the pins, the polygons and the legend are not touched by any of this: they
/// carry meaning, and the tint exists to match them, not to compete.
class CarrierTint {
  /// The icon's night blue (AppTheme.nightBlue): used when there is no carrier.
  static const Color neutral = Color(0xFF34406B);

  /// M3 baseline dark surface, what the dark roles blend toward.
  static const Color darkSurface = Color(0xFF1C1B1F);

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _black = Color(0xFF000000);

  /// The carrier name in large bold text (WCAG large text, 3:1 floor).
  final Color name;

  /// Chip background, e.g. the carrier chip on the site sheet or a technology chip.
  final Color chipBg;

  /// Text on [chipBg].
  final Color chipFg;

  /// A second, slightly stronger pill background (carrier aggregation on the Android card).
  final Color pillBg;

  /// Text on [pillBg].
  final Color pillFg;

  /// Links and small graphics such as a sparkline.
  final Color accent;

  /// Alternating segments of a proportional bar: the darker (light theme) or lighter (dark) one.
  final Color segA;

  /// The other segment: a wash toward the surface so the two alternate without shouting.
  final Color segB;

  /// The label on [segA]: white or [darkSurface], whichever contrasts more with the segment.
  final Color onSegA;

  /// The label on [segB].
  final Color onSegB;

  CarrierTint._({
    required this.name,
    required this.chipBg,
    required this.chipFg,
    required this.pillBg,
    required this.pillFg,
    required this.accent,
    required this.segA,
    required this.segB,
  })  : onSegA = labelOn(segA),
        onSegB = labelOn(segB);

  /// Derives the roles for [carrier] in the given theme. The alpha of [carrier] is ignored
  /// (TelcoHelper.getColor carries its own); every role comes back opaque.
  factory CarrierTint.of(Color carrier, {required bool dark}) {
    final Color c = Color(carrier.toARGB32() | 0xFF000000);
    if (dark) {
      return CarrierTint._(
        name: mix(c, _white, 0.40),
        chipBg: mix(c, darkSurface, 0.62),
        chipFg: mix(c, _white, 0.60),
        pillBg: mix(c, darkSurface, 0.58),
        pillFg: mix(c, _white, 0.65),
        accent: mix(c, _white, 0.50),
        segA: mix(c, _white, 0.25),
        segB: mix(c, darkSurface, 0.40),
      );
    }
    return CarrierTint._(
      name: mix(c, _black, 0.10),
      chipBg: mix(c, _white, 0.84),
      chipFg: mix(c, _black, 0.35),
      pillBg: mix(c, _white, 0.80),
      pillFg: mix(c, _black, 0.40),
      accent: mix(c, _black, 0.20),
      segA: mix(c, _black, 0.10),
      segB: mix(c, _white, 0.55),
    );
  }

  /// Linear per-channel blend from [a] toward [b]: `a + (b - a) * t` on red, green and blue,
  /// rounded to the nearest step; alpha is forced to 0xFF. A plain sRGB lerp, not a perceptual
  /// one: the contrast ratios were measured on exactly this.
  static Color mix(Color a, Color b, double t) {
    final int ia = a.toARGB32();
    final int ib = b.toARGB32();
    int channel(int shift) {
      final int x = (ia >> shift) & 0xFF;
      final int y = (ib >> shift) & 0xFF;
      return (x + (y - x) * t).round().clamp(0, 255);
    }

    return Color(0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0));
  }

  /// White or [darkSurface], whichever has the higher WCAG contrast against [bg].
  static Color labelOn(Color bg) {
    final double l = luminance(bg);
    final double onWhite = (1.0 + 0.05) / (l + 0.05);
    final double onDark = (l + 0.05) / (luminance(darkSurface) + 0.05);
    return onWhite >= onDark ? _white : darkSurface;
  }

  /// WCAG 2 relative luminance of an opaque sRGB colour.
  static double luminance(Color colour) {
    final int argb = colour.toARGB32();
    return 0.2126 * _linear((argb >> 16) & 0xFF) +
        0.7152 * _linear((argb >> 8) & 0xFF) +
        0.0722 * _linear(argb & 0xFF);
  }

  /// WCAG 2 contrast ratio, (L1 + 0.05) / (L2 + 0.05) with L1 the lighter.
  static double contrast(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static double _linear(int channel) {
    final double c = channel / 255.0;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }
}
