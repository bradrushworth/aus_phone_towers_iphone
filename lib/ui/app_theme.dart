import 'package:flutter/material.dart';

/// The app's colour roles and theme, in one place so a test can pin them.
///
/// Until 2026-09 both apps drew their chrome from Material 3's un-overridden baseline seed, the
/// purple #6750A4, which nobody had chosen: it clashed with Optus cyan and with the green signal
/// ramp, and matched nothing else on the screen. The owner's decision of 2026-09-06 ("option 2b:
/// carrier, tonal") moves the chrome to the night blue of the app icon and lets a surface that
/// belongs to one carrier take a tonal wash of that carrier's colour instead (see CarrierTint).
/// The eight role values below are the Android app's brand_* tokens (res/values/colors.xml and
/// values-night/colors.xml) and must stay in lockstep with them; test/ui/app_theme_test.dart
/// pins them.
class AppTheme {
  AppTheme._();

  /// The icon's night blue: the seed for every derived role and the light-theme primary.
  static const Color nightBlue = Color(0xFF34406B);

  static const Color lightPrimary = nightBlue;
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightContainer = Color(0xFFE3E8F3);
  static const Color lightOnContainer = Color(0xFF2E3A5C);

  static const Color darkPrimary = Color(0xFFB7C0D8);
  static const Color darkOnPrimary = Color(0xFF1E2742);
  static const Color darkContainer = Color(0xFF323C5A);
  static const Color darkOnContainer = Color(0xFFCBD5F0);

  /// The colour scheme for [brightness]: Material's tonal derivation from [nightBlue] for the
  /// roles nothing pins (surfaces, outline, error, tertiary), with the primary and secondary
  /// families set to the shared tokens so buttons, switches, chips and the Legend and Driving
  /// pills match the Android app exactly.
  static ColorScheme scheme(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final ColorScheme seeded =
        ColorScheme.fromSeed(seedColor: nightBlue, brightness: brightness);
    final Color primary = dark ? darkPrimary : lightPrimary;
    final Color onPrimary = dark ? darkOnPrimary : lightOnPrimary;
    final Color container = dark ? darkContainer : lightContainer;
    final Color onContainer = dark ? darkOnContainer : lightOnContainer;
    return seeded.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: container,
      onPrimaryContainer: onContainer,
      secondary: primary,
      onSecondary: onPrimary,
      secondaryContainer: container,
      onSecondaryContainer: onContainer,
    );
  }

  /// The full theme for [brightness]. Everything that is not a colour role is as it was when
  /// this lived in main.dart; see the comments on each item.
  static ThemeData build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final ColorScheme colours = scheme(brightness);
    return ThemeData(
        colorScheme: colours,
        appBarTheme: AppBarTheme(
            iconTheme: IconThemeData(color: dark ? Colors.grey[400] : Colors.grey, size: 32),
            elevation: 0.0,
            // The translucent bar over the map. Dark used to be a fixed purple-tinged near-black
            // from the old seed; it now takes the scheme's own surface so it agrees with the
            // bottom sheets, which already use colorScheme.surface.
            backgroundColor: (dark ? colours.surface : Colors.white).withValues(alpha: 0.85)),
        textTheme: TextTheme(
            // bodySmall is the cell-info row along the bottom of the map (map_common.dart
            // ~1690-1760). 10 sp of monospace was hard to read at a glance, which is the one
            // moment it has to be read, while driving. Nudged to 11.5; kept modest because those
            // rows are fixed-width and monospace, so a large jump risks clipping rather than
            // wrapping.
            bodySmall: TextStyle(
                fontFamily: 'RobotoMono',
                color: dark ? Colors.grey[300] : Colors.grey[800],
                fontSize: 11.5),
            labelLarge: TextStyle(color: dark ? Colors.grey[300] : Colors.grey[700])),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: dark ? Colors.grey[400]! : Colors.grey[700]!)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: dark ? Colors.grey[400]! : Colors.grey[700]!)),
        ),
        // map_common.dart references elevatedButtonTheme.style, which previously resolved to
        // null because no theme ever defined it.
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: colours.secondaryContainer,
                foregroundColor: colours.onSecondaryContainer)));
  }
}
