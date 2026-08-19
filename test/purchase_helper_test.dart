import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phonetowers/helpers/entitlement_evaluator.dart';

// Mirror of PurchaseHelper.EXPIRY_PERIOD (365 days in ms).
const int _expiryPeriod = 365 * 24 * 60 * 60 * 1000;

PurchaseDetails _purchase(String productId, String transactionDateMs,
    [PurchaseStatus status = PurchaseStatus.purchased]) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: '',
    ),
    transactionDate: transactionDateMs,
    status: status,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en-AU', null);
  });

  group('evaluateEntitlements (ad / subscription decision)', () {
    test('no purchases -> ads shown, not subscribed', () async {
      final PurchaseEntitlement e =
          await evaluateEntitlements([], nowMillis: 1, expiryPeriod: _expiryPeriod);
      expect(e.isDonated, isFalse);
      expect(e.isSubscribed, isFalse);
      expect(e.isSubscribedPermanently, isFalse);
      expect(e.yearlyPurchaseExpired, isFalse);
      expect(e.hasPurchaseProcessed, isTrue);
      expect(e.timeToExpireYearlySubscription, isEmpty);
    });

    test('donation only -> isDonated true but ads still shown', () async {
      final PurchaseEntitlement e = await evaluateEntitlements(
        [_purchase(skuDonationSmall, '0')],
        nowMillis: 1,
        expiryPeriod: _expiryPeriod,
      );
      // Donations must NOT remove ads.
      expect(e.isDonated, isTrue);
      expect(e.isSubscribed, isFalse);
      expect(e.isSubscribedPermanently, isFalse);
      expect(e.yearlyPurchaseExpired, isFalse);
    });

    test('yearly active -> subscribed, not permanent, expiry computed', () async {
      const int now = 1700000000000;
      final int purchasedAt = now - (_expiryPeriod - 1000); // 1s inside the window
      final PurchaseEntitlement e = await evaluateEntitlements(
        [_purchase(skuSubscribeOneYear, purchasedAt.toString())],
        nowMillis: now,
        expiryPeriod: _expiryPeriod,
      );
      expect(e.isSubscribed, isTrue);
      expect(e.isSubscribedPermanently, isFalse);
      expect(e.yearlyPurchaseExpired, isFalse);
      expect(e.timeToExpireYearlySubscription, startsWith('Expires '));
      expect(e.yearlyExpiryEpoch, purchasedAt + _expiryPeriod);
    });

    test('yearly exactly at expiry -> still active (boundary inclusive)', () async {
      const int now = 1700000000000;
      final int purchasedAt = now - _expiryPeriod; // boundary
      final PurchaseEntitlement e = await evaluateEntitlements(
        [_purchase(skuSubscribeOneYear, purchasedAt.toString())],
        nowMillis: now,
        expiryPeriod: _expiryPeriod,
      );
      expect(e.isSubscribed, isTrue);
      expect(e.yearlyPurchaseExpired, isFalse);
    });

    test('yearly expired -> not subscribed, flagged for consume', () async {
      const int now = 1700000000000;
      final int purchasedAt = now - _expiryPeriod - 1000; // 1s past the window
      final PurchaseEntitlement e = await evaluateEntitlements(
        [_purchase(skuSubscribeOneYear, purchasedAt.toString())],
        nowMillis: now,
        expiryPeriod: _expiryPeriod,
      );
      // Ads return and the caller should finish/consume the transaction.
      expect(e.isSubscribed, isFalse);
      expect(e.yearlyPurchaseExpired, isTrue);
      expect(e.timeToExpireYearlySubscription, isEmpty);
    });

    test('yearly active with StoreKit2 "yyyy-MM-dd HH:mm:ss" date -> subscribed', () async {
      // iOS StoreKit2 (in_app_purchase_storekit's default transaction path)
      // reports transactionDate as a local-time "yyyy-MM-dd HH:mm:ss" string
      // rather than epoch milliseconds. This must not be treated as expired/absent.
      final DateTime purchasedAt = DateTime.now().subtract(const Duration(days: 30));
      final String formatted =
          '${purchasedAt.year.toString().padLeft(4, '0')}-'
          '${purchasedAt.month.toString().padLeft(2, '0')}-'
          '${purchasedAt.day.toString().padLeft(2, '0')} '
          '${purchasedAt.hour.toString().padLeft(2, '0')}:'
          '${purchasedAt.minute.toString().padLeft(2, '0')}:'
          '${purchasedAt.second.toString().padLeft(2, '0')}';
      final PurchaseEntitlement e = await evaluateEntitlements(
        [_purchase(skuSubscribeOneYear, formatted)],
        nowMillis: DateTime.now().millisecondsSinceEpoch,
        expiryPeriod: _expiryPeriod,
      );
      expect(e.isSubscribed, isTrue);
      expect(e.yearlyPurchaseExpired, isFalse);
    });

    test('permanent -> subscribed and permanent forever', () async {
      final PurchaseEntitlement e = await evaluateEntitlements(
        [_purchase(skuSubscribePermanently, '0')],
        nowMillis: 1,
        expiryPeriod: _expiryPeriod,
      );
      expect(e.isSubscribed, isTrue);
      expect(e.isSubscribedPermanently, isTrue);
      expect(e.yearlyPurchaseExpired, isFalse);
      expect(e.timeToExpireYearlySubscription, isEmpty);
    });

    test('permanent + yearly together -> subscribed (permanent wins for permanence)', () async {
      final PurchaseEntitlement e = await evaluateEntitlements(
        [
          _purchase(skuSubscribeOneYear, '0'),
          _purchase(skuSubscribePermanently, '0'),
        ],
        nowMillis: 1,
        expiryPeriod: _expiryPeriod,
      );
      expect(e.isSubscribed, isTrue);
      expect(e.isSubscribedPermanently, isTrue);
    });

    test('null entries in the list are ignored', () async {
      final PurchaseEntitlement e = await evaluateEntitlements(
        [null, _purchase(skuDonationMedium, '0'), null],
        nowMillis: 1,
        expiryPeriod: _expiryPeriod,
      );
      expect(e.isDonated, isTrue);
      expect(e.isSubscribed, isFalse);
    });

    test('unknown product ids do not affect entitlement', () async {
      final PurchaseEntitlement e = await evaluateEntitlements(
        [_purchase('some_other_sku', '0')],
        nowMillis: 1,
        expiryPeriod: _expiryPeriod,
      );
      expect(e.isDonated, isFalse);
      expect(e.isSubscribed, isFalse);
    });
  });
}
