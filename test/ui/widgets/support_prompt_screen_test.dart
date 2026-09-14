import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/ui/widgets/support_prompt_screen.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';

ProductDetails _product(String id, String price) {
  return ProductDetails(
    id: id,
    title: id,
    description: '',
    price: price,
    rawPrice: 0,
    currencyCode: 'AUD',
  );
}

void main() {
  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider<PurchaseHelper>.value(
        value: PurchaseHelper(),
        child: const MaterialApp(home: SupportPromptScreen()),
      ),
    );
  }

  // PurchaseHelper is a singleton — reset the state this screen reads so it doesn't leak
  // between tests.
  tearDown(() {
    PurchaseHelper().isSubscribed = false;
    PurchaseHelper().debugProducts = [];
    PurchaseHelper().storefrontCountryCode = null;
    MapHelper().developerMode = false;
  });

  group('SupportPromptScreen', () {
    testWidgets('shows the title, message and all three donation options', (tester) async {
      await pump(tester);
      expect(find.text(Strings.supportPromptTitle), findsOneWidget);
      expect(find.text(Strings.supportPromptMessage), findsOneWidget);
      expect(find.text(Strings.donateSmallName), findsOneWidget);
      expect(find.text(Strings.donateMediumName), findsOneWidget);
      expect(find.text(Strings.donateLargeName), findsOneWidget);
      expect(find.text(Strings.supportPromptMaybeLater), findsOneWidget);
    });

    testWidgets('shows the ad-free options when the user is not yet ad-free', (tester) async {
      PurchaseHelper().isSubscribed = false;
      await pump(tester);
      expect(find.text(Strings.supportPromptAdfreeHeader), findsOneWidget);
      expect(find.text(Strings.remove_ads_year_name), findsOneWidget);
      expect(find.text(Strings.remove_ads_permanent_name), findsOneWidget);
    });

    testWidgets('hides the ad-free section once the user already has ads removed',
        (tester) async {
      PurchaseHelper().isSubscribed = true;
      await pump(tester);
      expect(find.text(Strings.supportPromptAdfreeHeader), findsNothing);
      expect(find.text(Strings.remove_ads_year_name), findsNothing);
      expect(find.text(Strings.remove_ads_permanent_name), findsNothing);
    });

    testWidgets('shows live store pricing once product details have loaded, not the hardcoded fallback',
        (tester) async {
      PurchaseHelper().debugProducts = [
        _product(PurchaseHelper.SKU_DONATION_SMALL, '\$1.23'),
        _product(PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR, '\$4.56'),
      ];
      await pump(tester);
      expect(find.text('${Strings.donateSmallName} (\$1.23)'), findsOneWidget);
      expect(find.text(Strings.donateSmallName), findsNothing);
      expect(find.text('${Strings.remove_ads_year_name} (\$4.56)'), findsOneWidget);
      expect(find.text(Strings.remove_ads_year_name), findsNothing);
      // Products with no matching entry in the store response still fall back.
      expect(find.text(Strings.donateMediumName), findsOneWidget);
    });

    // bead aptios-589: once App Store Connect has yearly_adfree_pass, the button must price and
    // buy that id instead of the legacy consumable it replaces.
    testWidgets('prices the yearly_adfree_pass once the store returns it, not the legacy consumable',
        (tester) async {
      PurchaseHelper().debugProducts = [
        _product(PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR, '\$4.56'),
        _product(PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR_PASS, '\$5.67'),
      ];
      await pump(tester);
      expect(find.text('${Strings.remove_ads_year_name} (\$5.67)'), findsOneWidget);
      expect(find.text('${Strings.remove_ads_year_name} (\$4.56)'), findsNothing);
    });

    // The store diagnostics exist to attribute a price that disagrees with the store's own
    // purchase sheet — to a storefront or currency difference — rather than leaving it to be
    // guessed at. They are diagnostic, so they must stay out of the way of everyone else.
    testWidgets('hides the store diagnostics outside developer mode', (tester) async {
      MapHelper().developerMode = false;
      PurchaseHelper().debugProducts = [
        _product(PurchaseHelper.SKU_DONATION_SMALL, '\$1.23'),
      ];
      await pump(tester);
      expect(find.text(Strings.supportPromptStoreDiagnosticsHeader), findsNothing);
    });

    testWidgets('shows the storefront and the currency of each price in developer mode',
        (tester) async {
      MapHelper().developerMode = true;
      PurchaseHelper().storefrontCountryCode = 'AUS';
      PurchaseHelper().debugProducts = [
        _product(PurchaseHelper.SKU_DONATION_SMALL, '\$1.23'),
      ];
      await pump(tester);

      expect(find.text(Strings.supportPromptStoreDiagnosticsHeader), findsOneWidget);
      final String report = PurchaseHelper().storeDiagnostics;
      expect(report, contains('Storefront: AUS'));
      expect(report, contains('${PurchaseHelper.SKU_DONATION_SMALL}: \$1.23'));
      expect(report, contains('AUD'));
      expect(find.text(report), findsOneWidget);
    });
  });

  group('PurchaseHelper.storeDiagnostics', () {
    tearDown(() {
      PurchaseHelper().debugProducts = [];
      PurchaseHelper().storefrontCountryCode = null;
    });

    test('says the storefront is unknown rather than implying a default one', () {
      PurchaseHelper().storefrontCountryCode = null;
      PurchaseHelper().debugProducts = [];
      expect(PurchaseHelper().storeDiagnostics,
          'Storefront: unknown\nNo products loaded.');
    });

    test('reports the raw amount and currency code beside the display price', () {
      PurchaseHelper().storefrontCountryCode = 'USA';
      PurchaseHelper().debugProducts = [
        ProductDetails(
          id: PurchaseHelper.SKU_DONATION_SMALL,
          title: 'Morning Coffee',
          description: '',
          price: '\$1.23',
          rawPrice: 1.23,
          currencyCode: 'USD',
        ),
      ];
      expect(
        PurchaseHelper().storeDiagnostics,
        'Storefront: USA\n${PurchaseHelper.SKU_DONATION_SMALL}: \$1.23  (1.23 USD)',
      );
    });
  });
}
