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
