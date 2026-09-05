import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart' show SK2Transaction;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:phonetowers/billing/entitlement_cache.dart';
import 'package:phonetowers/billing/restore_outcome.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';

/// Regression coverage for the September 2026 report against 1.14.16: "bought no-ads three times,
/// Restore Purchases does nothing, ads still show". Exercises PurchaseHelper's restore path with
/// the store and the StoreKit 2 transaction history injected, so none of it needs a platform
/// channel.
PurchaseDetails _purchase(
  String productId, {
  required PurchaseStatus status,
  String transactionDateMs = '1700000000000',
  String? purchaseId,
  String localVerificationData = '',
}) {
  return PurchaseDetails(
    productID: productId,
    purchaseID: purchaseId,
    verificationData: PurchaseVerificationData(
      localVerificationData: localVerificationData,
      serverVerificationData: '',
      source: 'app_store',
    ),
    transactionDate: transactionDateMs,
    status: status,
  );
}

SK2Transaction _historyTx(String id, String productId, int purchaseDateMs,
    {int? revocationDateMs}) {
  final String revocation =
      revocationDateMs == null ? '' : ',"revocationDate":$revocationDateMs,"revocationReason":0';
  return SK2Transaction(
    id: id,
    originalId: id,
    productId: productId,
    purchaseDate: purchaseDateMs.toString(),
    appAccountToken: null,
    jsonRepresentation:
        '{"transactionId":"$id","productId":"$productId","purchaseDate":$purchaseDateMs$revocation}',
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en-AU', null);
  });

  late List<String> messages;

  // PurchaseHelper is a singleton — put every field this suite touches back to its cold-start
  // value so nothing leaks between cases (or from the other suites sharing this isolate).
  void resetPurchaseHelper() {
    final PurchaseHelper helper = PurchaseHelper();
    helper.isSubscribed = false;
    helper.isSubscribedPermanently = false;
    helper.hasPurchaseProcessed = false;
    helper.debugPurchases = [];
    helper.debugProducts = [];
    helper.debugStoreRestore = null;
    helper.debugTransactionHistory = null;
    helper.restoreBatchTimeout = const Duration(milliseconds: 50);
    messages = <String>[];
    helper.showSnackBar = ({required String message, Duration? duration, bool isDismissible = false}) {
      messages.add(message);
    };
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetPurchaseHelper();
  });
  tearDown(resetPurchaseHelper);

  group('restored transactions are delivered silently', () {
    test('a restore applies the entitlement without thanking the user for a new purchase',
        () async {
      await PurchaseHelper().deliverProduct(
        _purchase(PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY, status: PurchaseStatus.restored),
        <String, Object>{},
      );

      expect(PurchaseHelper().isSubscribedPermanently, isTrue);
      expect(messages, isEmpty,
          reason: 'restores happen on every cold start; a thank-you there reads as a new charge');
    });

    test('a fresh purchase still thanks the user', () async {
      await PurchaseHelper().deliverProduct(
        _purchase(PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY, status: PurchaseStatus.purchased),
        <String, Object>{},
      );

      expect(PurchaseHelper().isSubscribedPermanently, isTrue);
      expect(messages.where((m) => m.startsWith('Thanks')), hasLength(1));
    });
  });

  group('initiatePurchase refuses to sell ad-free the user already holds', () {
    test('permanent is refused when the permanent entitlement is already held',
        () async {
      PurchaseHelper().isSubscribed = true;
      PurchaseHelper().isSubscribedPermanently = true;

      await PurchaseHelper().initiatePurchase(sku: PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY);

      expect(messages, hasLength(1));
      expect(messages.single.toLowerCase(), contains('already'));
      expect(messages.single, contains('Restore Purchases'));
    });

    test('yearly is refused while any ad-free entitlement is active', () async {
      PurchaseHelper().isSubscribed = true;
      PurchaseHelper().isSubscribedPermanently = false;

      await PurchaseHelper().initiatePurchase(sku: PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR);

      expect(messages, hasLength(1));
      expect(messages.single.toLowerCase(), contains('already'));
    });

    test('upgrading from an active yearly to permanent is not blocked by the guard',
        () async {
      PurchaseHelper().isSubscribed = true;
      PurchaseHelper().isSubscribedPermanently = false;

      await PurchaseHelper().initiatePurchase(sku: PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY);

      // With no products loaded it falls through to the inventory message — the point is that
      // the entitlement guard did not fire.
      expect(messages.any((m) => m.toLowerCase().contains('already')), isFalse);
    });

    test('donations are never blocked by the entitlement guard', () async {
      PurchaseHelper().isSubscribed = true;
      PurchaseHelper().isSubscribedPermanently = true;

      await PurchaseHelper().initiatePurchase(sku: PurchaseHelper.SKU_DONATION_SMALL);

      expect(messages.any((m) => m.toLowerCase().contains('already')), isFalse);
    });
  });

  group('restorePurchases', () {
    test('a restore that finds nothing clears a stale cached entitlement', () async {
      // Seeded from a previous session (e.g. a purchase since refunded).
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await EntitlementCache.savePermanent(prefs);
      await PurchaseHelper().loadCachedEntitlement(nowMillis: 1000);
      expect(PurchaseHelper().isSubscribed, isTrue);

      PurchaseHelper().debugStoreRestore = () async {};
      PurchaseHelper().debugTransactionHistory = () async => <SK2Transaction>[];

      await PurchaseHelper().restorePurchases();

      expect(PurchaseHelper().isSubscribed, isFalse);
      expect(EntitlementCache.read(prefs, nowMillis: 1000).isSubscribed, isFalse);
    });

    test('a failed store restore leaves the cached entitlement alone', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await EntitlementCache.savePermanent(prefs);
      await PurchaseHelper().loadCachedEntitlement(nowMillis: 1000);

      PurchaseHelper().debugStoreRestore = () async => throw Exception('store offline');
      PurchaseHelper().debugTransactionHistory = () async => <SK2Transaction>[];

      await PurchaseHelper().restorePurchases();

      expect(PurchaseHelper().isSubscribed, isTrue,
          reason: 'no answer from the store is not the same as "no purchase"');
      expect(EntitlementCache.read(prefs, nowMillis: 1000).isSubscribed, isTrue);
      expect(messages.single, startsWith('Failed to restore purchases'));
    });

    test('a failed history read leaves the cached entitlement alone', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await EntitlementCache.savePermanent(prefs);
      await PurchaseHelper().loadCachedEntitlement(nowMillis: 1000);

      PurchaseHelper().debugStoreRestore = () async {};
      PurchaseHelper().debugTransactionHistory = () async => throw Exception('no history');

      await PurchaseHelper().restorePurchases();

      expect(PurchaseHelper().isSubscribed, isTrue);
    });

    test('an ad-free purchase only present in the transaction history is restored',
        () async {
      // The plugin's own restore walks Transaction.currentEntitlements, which never contains a
      // consumable — so a "no ads" product configured as a consumable in App Store Connect is
      // invisible to it. Transaction.all (with SKIncludeConsumableInAppPurchaseHistory) is not.
      PurchaseHelper().debugStoreRestore = () async {};
      PurchaseHelper().debugTransactionHistory = () async => <SK2Transaction>[
            _historyTx('7', PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY, 1700000000000),
          ];

      await PurchaseHelper().restorePurchases();

      expect(PurchaseHelper().isSubscribedPermanently, isTrue);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(EntitlementCache.read(prefs, nowMillis: 1700000001000).isSubscribedPermanently, isTrue);
    });

    test('a refunded purchase in the history does not restore', () async {
      PurchaseHelper().debugStoreRestore = () async {};
      PurchaseHelper().debugTransactionHistory = () async => <SK2Transaction>[
            _historyTx('7', PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY, 1700000000000,
                revocationDateMs: 1700000500000),
          ];

      await PurchaseHelper().restorePurchases();

      expect(PurchaseHelper().isSubscribed, isFalse);
    });

    test('a store restore that arrives on the purchase stream is awaited and reported',
        () async {
      PurchaseHelper().debugStoreRestore = () async {
        // The plugin delivers restored transactions asynchronously on purchaseStream, after
        // (or racing) the restorePurchases() future itself.
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          PurchaseHelper().handlePurchaseUpdates([
            _purchase(PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY,
                status: PurchaseStatus.restored, purchaseId: '42'),
          ]);
        });
      };
      PurchaseHelper().debugTransactionHistory = () async => <SK2Transaction>[];

      await PurchaseHelper().restorePurchases(userInitiated: true);

      expect(PurchaseHelper().isSubscribedPermanently, isTrue);
      expect(messages.last, restoreOutcomeMessage(isSubscribed: true));
    });

    test('a user-initiated restore that finds nothing says so', () async {
      PurchaseHelper().debugStoreRestore = () async {};
      PurchaseHelper().debugTransactionHistory = () async => <SK2Transaction>[];

      await PurchaseHelper().restorePurchases(userInitiated: true);

      expect(messages.last, restoreOutcomeMessage(isSubscribed: false));
    });
  });

  group('revocations on the live purchase stream', () {
    test('a refund notification withdraws the entitlement instead of re-granting it',
        () async {
      // StoreKit 2's Transaction.updates emits the revoked transaction when Apple refunds it,
      // and the plugin forwards it with status "purchased" — only the payload says otherwise.
      await PurchaseHelper().handlePurchaseUpdates([
        _purchase(PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY,
            status: PurchaseStatus.purchased,
            localVerificationData: '{"productId":"permanent_adfree","purchaseDate":1700000000000}'),
      ]);
      expect(PurchaseHelper().isSubscribedPermanently, isTrue);

      await PurchaseHelper().handlePurchaseUpdates([
        _purchase(PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY,
            status: PurchaseStatus.purchased,
            localVerificationData:
                '{"productId":"permanent_adfree","purchaseDate":1700000000000,"revocationDate":1700000500000,"revocationReason":0}'),
      ]);

      expect(PurchaseHelper().isSubscribed, isFalse);
      expect(PurchaseHelper().isSubscribedPermanently, isFalse);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(EntitlementCache.read(prefs, nowMillis: 1700000001000).isSubscribed, isFalse);
    });
  });
}
