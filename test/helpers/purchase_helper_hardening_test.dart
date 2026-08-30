import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:phonetowers/billing/entitlement_cache.dart';
import 'package:phonetowers/billing/restore_outcome.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';

PurchaseDetails _purchase(String productId, String transactionDateMs) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: '',
    ),
    transactionDate: transactionDateMs,
    status: PurchaseStatus.purchased,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en-AU', null);
  });

  // PurchaseHelper is a singleton — reset the fields this suite touches so
  // state can't leak between cases (and between suites run in the same
  // isolate).
  void resetPurchaseHelper() {
    final PurchaseHelper helper = PurchaseHelper();
    helper.isSubscribed = false;
    helper.isSubscribedPermanently = false;
    helper.hasPurchaseProcessed = false;
    helper.debugPurchases = [];
    helper.showSnackBar = ({required String message, Duration? duration, bool isDismissible = false}) {};
  }

  setUp(resetPurchaseHelper);
  tearDown(resetPurchaseHelper);

  group('PurchaseHelper.loadCachedEntitlement (Fix 1: cold-start seed)', () {
    testWidgets('nothing cached -> isSubscribed stays false', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await PurchaseHelper().loadCachedEntitlement(nowMillis: 1000);

      expect(PurchaseHelper().isSubscribed, isFalse);
      expect(PurchaseHelper().isSubscribedPermanently, isFalse);
    });

    testWidgets('permanent cached -> isSubscribed true immediately', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await EntitlementCache.savePermanent(prefs);

      await PurchaseHelper().loadCachedEntitlement(nowMillis: 1000);

      expect(PurchaseHelper().isSubscribed, isTrue);
      expect(PurchaseHelper().isSubscribedPermanently, isTrue);
    });

    testWidgets('yearly cached unexpired -> isSubscribed true', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await EntitlementCache.saveYearly(prefs, yearlyExpiryEpoch: 5000);

      await PurchaseHelper().loadCachedEntitlement(nowMillis: 4000);

      expect(PurchaseHelper().isSubscribed, isTrue);
      expect(PurchaseHelper().isSubscribedPermanently, isFalse);
    });

    testWidgets('yearly cached expired -> isSubscribed false', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await EntitlementCache.saveYearly(prefs, yearlyExpiryEpoch: 5000);

      await PurchaseHelper().loadCachedEntitlement(nowMillis: 6000);

      expect(PurchaseHelper().isSubscribed, isFalse);
    });
  });

  group('PurchaseHelper._hasPurchase writes the cache (Fix 1: store overwrites seed)', () {
    testWidgets('permanent purchase from the store persists to the cache', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final PurchaseHelper helper = PurchaseHelper();

      await helper.deliverProduct(
        _purchase(PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY, '0'),
        <String, Object>{},
      );

      final prefs = await SharedPreferences.getInstance();
      final cached = EntitlementCache.read(prefs, nowMillis: 1000);
      expect(cached.isSubscribed, isTrue);
      expect(cached.isSubscribedPermanently, isTrue);
    });

    testWidgets('no purchases -> cache is cleared', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await EntitlementCache.savePermanent(prefs);

      // Calling deliverProduct with an unrelated donation re-runs _hasPurchase
      // against the (still empty) real purchase list, which must overwrite a
      // stale cached entitlement rather than leave it in place.
      await PurchaseHelper().deliverProduct(
        _purchase(PurchaseHelper.SKU_DONATION_SMALL, '0'),
        <String, Object>{},
      );

      final cached = EntitlementCache.read(prefs, nowMillis: 1000);
      expect(cached.isSubscribed, isFalse);
      expect(cached.isSubscribedPermanently, isFalse);
    });
  });

  group('Fix 3: deliverProduct is null-safe for purchaseID', () {
    testWidgets('null purchaseID does not throw and entitlement still applies', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final PurchaseHelper helper = PurchaseHelper();

      final PurchaseDetails details = PurchaseDetails(
        productID: PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: '',
        ),
        transactionDate: '0',
        status: PurchaseStatus.purchased,
      );
      expect(details.purchaseID, isNull);

      await helper.deliverProduct(details, <String, Object>{});

      expect(helper.isSubscribedPermanently, isTrue);
    });
  });

  group('Fix 2: restoreOutcomeMessage (pure, testable without the platform channel)', () {
    test('subscribed -> success message', () {
      expect(
        restoreOutcomeMessage(isSubscribed: true),
        'Purchases restored — you are ad-free.',
      );
    });

    test('not subscribed -> nothing-found message', () {
      expect(
        restoreOutcomeMessage(isSubscribed: false),
        'Restore complete. No ad-free purchase was found for this store account.',
      );
    });
  });
}
