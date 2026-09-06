import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/carrier_tint.dart';
import 'package:phonetowers/ui/app_theme.dart';

/// Pins the eight colour-role tokens the two apps share (the Android app's brand_* resources)
/// and that the Material baseline purple, which the app inherited for years by never overriding
/// its seed, cannot come back through any pinned role.
void main() {
  const Color purple = Color(0xFF6750A4);

  test('light roles are the shared brand tokens', () {
    final ColorScheme s = AppTheme.scheme(Brightness.light);
    expect(s.brightness, Brightness.light);
    expect(s.primary, const Color(0xFF34406B));
    expect(s.onPrimary, const Color(0xFFFFFFFF));
    expect(s.primaryContainer, const Color(0xFFE3E8F3));
    expect(s.onPrimaryContainer, const Color(0xFF2E3A5C));
    expect(s.secondary, s.primary);
    expect(s.secondaryContainer, s.primaryContainer);
    expect(s.onSecondaryContainer, s.onPrimaryContainer);
  });

  test('dark roles are the shared brand tokens', () {
    final ColorScheme s = AppTheme.scheme(Brightness.dark);
    expect(s.brightness, Brightness.dark);
    expect(s.primary, const Color(0xFFB7C0D8));
    expect(s.onPrimary, const Color(0xFF1E2742));
    expect(s.primaryContainer, const Color(0xFF323C5A));
    expect(s.onPrimaryContainer, const Color(0xFFCBD5F0));
    expect(s.secondary, s.primary);
    expect(s.secondaryContainer, s.primaryContainer);
    expect(s.onSecondaryContainer, s.onPrimaryContainer);
  });

  test('the baseline purple is gone from every role a widget draws chrome from', () {
    for (final Brightness b in Brightness.values) {
      final ColorScheme s = AppTheme.scheme(b);
      for (final Color c in <Color>[
        s.primary,
        s.primaryContainer,
        s.secondary,
        s.secondaryContainer,
        s.tertiary,
        s.tertiaryContainer,
        s.surfaceTint,
        s.inversePrimary,
      ]) {
        expect(c, isNot(purple), reason: '$b');
      }
    }
  });

  test('text on the pinned surfaces meets 4.5:1 in both themes', () {
    for (final Brightness b in Brightness.values) {
      final ColorScheme s = AppTheme.scheme(b);
      expect(CarrierTint.contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5),
          reason: '$b primary');
      expect(CarrierTint.contrast(s.onPrimaryContainer, s.primaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$b container');
    }
  });

  test('the theme builds for both brightnesses and buttons use the container', () {
    final ThemeData dark = AppTheme.build(Brightness.dark);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.elevatedButtonTheme.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppTheme.darkContainer);
    expect(dark.elevatedButtonTheme.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppTheme.darkOnContainer);
    final ThemeData light = AppTheme.build(Brightness.light);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(light.elevatedButtonTheme.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppTheme.lightContainer);
  });

  test('the neutral carrier tint is the theme seed', () {
    expect(CarrierTint.neutral, AppTheme.nightBlue);
  });
}
