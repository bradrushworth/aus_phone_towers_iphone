import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart' show SK2Transaction;

import 'package:phonetowers/billing/transaction_history.dart';

/// Builds an [SK2Transaction] the way the plugin's `Transaction.all` wrapper does, with a
/// `jsonRepresentation` shaped like StoreKit 2's decoded JWS transaction payload.
SK2Transaction _tx(
  String id,
  String productId,
  int purchaseDateMs, {
  int? revocationDateMs,
  String type = 'Non-Consumable',
}) {
  final StringBuffer json = StringBuffer('{')
    ..write('"transactionId":"$id",')
    ..write('"originalTransactionId":"$id",')
    ..write('"productId":"$productId",')
    ..write('"type":"$type",')
    ..write('"purchaseDate":$purchaseDateMs');
  if (revocationDateMs != null) {
    json.write(',"revocationDate":$revocationDateMs,"revocationReason":0');
  }
  json.write('}');
  return SK2Transaction(
    id: id,
    originalId: id,
    productId: productId,
    purchaseDate: purchaseDateMs.toString(),
    appAccountToken: null,
    jsonRepresentation: json.toString(),
  );
}

void main() {
  group('StoreKitTransactionJson.isRevoked', () {
    test('null, empty and malformed JSON are not revoked', () {
      expect(StoreKitTransactionJson.isRevoked(null), isFalse);
      expect(StoreKitTransactionJson.isRevoked(''), isFalse);
      expect(StoreKitTransactionJson.isRevoked('not json'), isFalse);
      expect(StoreKitTransactionJson.isRevoked('[1,2]'), isFalse);
    });

    test('a transaction without a revocationDate is not revoked', () {
      expect(
        StoreKitTransactionJson.isRevoked('{"productId":"permanent_adfree","purchaseDate":1}'),
        isFalse,
      );
      // An explicit null must read the same as an absent key.
      expect(
        StoreKitTransactionJson.isRevoked('{"productId":"permanent_adfree","revocationDate":null}'),
        isFalse,
      );
    });

    test('a refunded transaction carries a revocationDate and is revoked', () {
      expect(
        StoreKitTransactionJson.isRevoked(
            '{"productId":"permanent_adfree","revocationDate":1700000500000,"revocationReason":0}'),
        isTrue,
      );
    });
  });

  group('StoreKitTransactionJson.productType', () {
    test('reads the App Store product type from the payload', () {
      expect(StoreKitTransactionJson.productType('{"type":"Consumable"}'), 'Consumable');
      expect(StoreKitTransactionJson.productType('{"type":"Non-Consumable"}'), 'Non-Consumable');
    });

    test('is null when absent or unparseable', () {
      expect(StoreKitTransactionJson.productType(null), isNull);
      expect(StoreKitTransactionJson.productType('{}'), isNull);
      expect(StoreKitTransactionJson.productType('garbage'), isNull);
    });
  });

  group('adFreeRestoresFromHistory', () {
    test('empty history restores nothing', () {
      expect(adFreeRestoresFromHistory(const <SK2Transaction>[]), isEmpty);
    });

    test('donations and unknown products are ignored', () {
      final List<PurchaseDetails> restores = adFreeRestoresFromHistory([
        _tx('1', 'donation_small', 1000, type: 'Consumable'),
        _tx('2', 'donation_large', 2000, type: 'Consumable'),
        _tx('3', 'something_else', 3000),
      ]);
      expect(restores, isEmpty);
    });

    test('an un-revoked ad-free purchase is expressed as a restored PurchaseDetails', () {
      final List<PurchaseDetails> restores = adFreeRestoresFromHistory([
        _tx('1001', 'permanent_adfree', 1700000000000),
      ]);
      expect(restores, hasLength(1));
      final PurchaseDetails restored = restores.single;
      expect(restored.productID, 'permanent_adfree');
      expect(restored.purchaseID, '1001');
      expect(restored.transactionDate, '1700000000000');
      expect(restored.status, PurchaseStatus.restored);
      // A history-sourced restore is never a fresh purchase, so it must never be "finished".
      expect(restored.pendingCompletePurchase, isFalse);
      // The payload rides along so downstream revocation checks keep working.
      expect(restored.verificationData.localVerificationData, contains('"productId":"permanent_adfree"'));
    });

    test('a refunded (revoked) ad-free purchase is not restored', () {
      final List<PurchaseDetails> restores = adFreeRestoresFromHistory([
        _tx('1001', 'permanent_adfree', 1700000000000, revocationDateMs: 1700000500000),
      ]);
      expect(restores, isEmpty);
    });

    test('the newest un-revoked transaction wins for a SKU bought more than once', () {
      // The reported case: a yearly pass charged three times, two of them since refunded. The
      // one that still stands must set the expiry, regardless of list order.
      final List<PurchaseDetails> restores = adFreeRestoresFromHistory([
        _tx('3', 'yearly_adfree', 3000, type: 'Consumable', revocationDateMs: 3500),
        _tx('1', 'yearly_adfree', 1000, type: 'Consumable'),
        _tx('2', 'yearly_adfree', 2000, type: 'Consumable', revocationDateMs: 2500),
        _tx('0', 'yearly_adfree', 500, type: 'Consumable'),
      ]);
      expect(restores, hasLength(1));
      expect(restores.single.purchaseID, '1');
      expect(restores.single.transactionDate, '1000');
    });

    test('yearly and permanent are restored independently', () {
      final List<PurchaseDetails> restores = adFreeRestoresFromHistory([
        _tx('10', 'yearly_adfree', 1000),
        _tx('20', 'permanent_adfree', 2000),
      ]);
      expect(restores.map((p) => p.productID), containsAll(['yearly_adfree', 'permanent_adfree']));
      expect(restores, hasLength(2));
    });

    test('a transaction with no parseable purchase date still restores (as the oldest)', () {
      final SK2Transaction undated = SK2Transaction(
        id: '5',
        originalId: '5',
        productId: 'permanent_adfree',
        purchaseDate: '',
        appAccountToken: null,
        jsonRepresentation: '{"productId":"permanent_adfree"}',
      );
      final List<PurchaseDetails> restores = adFreeRestoresFromHistory([undated]);
      expect(restores, hasLength(1));
      expect(restores.single.purchaseID, '5');
    });
  });
}
