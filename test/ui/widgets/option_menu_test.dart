import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/ui/widgets/option_menu.dart';

/// The overflow menu's composition is a convention shared with the Android app's
/// `popup_menu.xml`, and it drifts silently — nothing else in the app fails when a row is added
/// in the wrong place, or when something that belongs in a sheet reappears here.
///
/// See the doc comment on [OptionMenuItem] for the two deliberate differences from
/// `popup_menu.xml` (no leaderboard, no Close App).
void main() {
  group('OptionMenuItem', () {
    test('matches the Android overflow, in order', () {
      expect(OptionMenuItem.values.map((item) => item.name).toList(), <String>[
        'refreshData',
        'exportData',
        'settings',
        'userGuide',
        'reportProblem',
        'supportTheApp',
      ]);
    });

    test('sells nothing: purchases belong to SupportPromptScreen alone', () {
      // Remove Ads and Donate submenus used to live here, which is how the app came to offer the
      // same five products from three different places.
      final names = OptionMenuItem.values.map((item) => item.name.toLowerCase()).join(' ');
      expect(names.contains('donate'), isFalse);
      expect(names.contains('removeads'), isFalse);
      expect(names.contains('subscribe'), isFalse);
    });
  });
}
