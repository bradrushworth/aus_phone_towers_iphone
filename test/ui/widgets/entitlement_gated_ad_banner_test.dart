import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/ui/widgets/entitlement_gated_ad_banner.dart';

void main() {
  // PurchaseHelper is a singleton — reset the entitlement flags each test so
  // state can't leak between cases.
  setUp(() {
    PurchaseHelper().isSubscribed = false;
    PurchaseHelper().isSubscribedPermanently = false;
  });

  tearDown(() {
    PurchaseHelper().isSubscribed = false;
    PurchaseHelper().isSubscribedPermanently = false;
  });

  Future<void> pump(
    WidgetTester tester, {
    required Size? Function() adSize,
    required Widget? Function() adChild,
  }) {
    return tester.pumpWidget(
      ChangeNotifierProvider<PurchaseHelper>.value(
        value: PurchaseHelper(),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EntitlementGatedAdBanner(adSize: adSize, adChild: adChild),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final Finder banner = find.byKey(const Key('ad-banner-outer'));

  group('EntitlementGatedAdBanner', () {
    testWidgets('not subscribed -> banner region is visible', (tester) async {
      await pump(
        tester,
        adSize: () => const Size(320, 50),
        adChild: () => Container(key: const Key('fake-ad-view')),
      );

      expect(banner, findsOneWidget);
      expect(find.text('Advertisement'), findsOneWidget);
      expect(find.byKey(const Key('fake-ad-view')), findsOneWidget);
    });

    testWidgets('already subscribed at first build -> banner region is absent',
        (tester) async {
      PurchaseHelper().isSubscribed = true;

      await pump(
        tester,
        adSize: () => const Size(320, 50),
        adChild: () => Container(key: const Key('fake-ad-view')),
      );

      expect(banner, findsNothing);
      expect(find.text('Advertisement'), findsNothing);
    });

    testWidgets(
        'entitlement arriving AFTER the ad is on screen hides the banner '
        'without any unrelated parent rebuild', (tester) async {
      // Regression test for "I paid to remove ads but the ads still appear":
      // the banner used to be gated on PurchaseHelper().isSubscribed OUTSIDE
      // any Consumer, so when restorePurchases()/a purchase completed and
      // notifyListeners() fired, the already-rendered ad strip stayed on
      // screen until some unrelated setState rebuilt the map UI.
      Size? currentAdSize = const Size(320, 50);
      Widget? currentAdChild = Container(key: const Key('fake-ad-view'));

      await pump(
        tester,
        adSize: () => currentAdSize,
        adChild: () => currentAdChild,
      );
      expect(banner, findsOneWidget);

      // Simulate PurchaseHelper._hasPurchase() recognising a restored
      // ad-free purchase: entitlement flips and listeners are notified —
      // and (as AdsHelper().hideBannerAd() does) the ad is torn down.
      currentAdSize = null;
      currentAdChild = null;
      PurchaseHelper().isSubscribed = true;
      PurchaseHelper().notifyListeners();
      await tester.pump();

      expect(banner, findsNothing);
      expect(find.text('Advertisement'), findsNothing);
      expect(find.byKey(const Key('fake-ad-view')), findsNothing);
    });

    testWidgets(
        'entitlement lapsing mid-session (yearly expiry) shows the banner again',
        (tester) async {
      PurchaseHelper().isSubscribed = true;

      Size? currentAdSize;
      Widget? currentAdChild;

      await pump(
        tester,
        adSize: () => currentAdSize,
        adChild: () => currentAdChild,
      );
      expect(banner, findsNothing);

      currentAdSize = const Size(320, 50);
      currentAdChild = Container(key: const Key('fake-ad-view'));
      PurchaseHelper().isSubscribed = false;
      PurchaseHelper().notifyListeners();
      await tester.pump();

      expect(banner, findsOneWidget);
      expect(find.byKey(const Key('fake-ad-view')), findsOneWidget);
    });
  });
}
