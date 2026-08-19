import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/ui/widgets/ad_banner_container.dart';

void main() {
  Future<void> pump(WidgetTester tester, AdBannerContainer widget) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
  }

  final Finder outer = find.byKey(const Key('ad-banner-outer'));

  group('AdBannerContainer', () {
    testWidgets('no ad loaded -> collapses to zero size and hides label', (tester) async {
      await pump(tester, const AdBannerContainer(adSize: null, adChild: null));

      expect(tester.getSize(outer).height, 0);
      expect(find.text('Advertisement'), findsNothing);

      final SizedBox box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, 0);
      expect(box.height, 0);
    });

    testWidgets('ad loaded -> sizes itself from the platform-reported adSize, not a placeholder',
        (tester) async {
      // Regression test for the bug where inline adaptive banner ads loaded
      // successfully but never appeared: the widget was sized from the
      // *requested* AdSize, which always reports height 0 for inline
      // adaptive banners. It must instead use the real size returned by
      // BannerAd.getPlatformAdSize() once the ad has loaded.
      const Size loadedSize = Size(320, 50);
      final Widget adPlaceholder = Container(key: const Key('fake-ad-view'));

      await pump(tester, AdBannerContainer(adSize: loadedSize, adChild: adPlaceholder));

      expect(tester.getSize(outer).height, 100);
      expect(find.text('Advertisement'), findsOneWidget);

      final SizedBox box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, loadedSize.width);
      expect(box.height, loadedSize.height);

      // The ad content itself is actually mounted in the tree, not swapped
      // for the empty placeholder.
      expect(find.byKey(const Key('fake-ad-view')), findsOneWidget);
    });

    testWidgets('adSize known but adChild not yet supplied -> renders empty placeholder',
        (tester) async {
      await pump(tester, const AdBannerContainer(adSize: Size(320, 50), adChild: null));

      final SizedBox box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.child, isA<Container>());
    });
  });
}
