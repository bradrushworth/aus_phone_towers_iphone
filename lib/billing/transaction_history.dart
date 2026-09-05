import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart' show SK2Transaction;

import '../helpers/entitlement_evaluator.dart' show skuSubscribeOneYear, skuSubscribePermanently;

/// The two products that remove ads. Everything else in the store (the donations) is a
/// consumable that neither grants nor needs an entitlement, so the history scan ignores it.
const Set<String> kAdFreeProductIds = <String>{skuSubscribeOneYear, skuSubscribePermanently};

/// Pure readers over a StoreKit 2 transaction's `jsonRepresentation` — the decoded JWS
/// transaction payload Apple documents as `JWSTransactionDecodedPayload`. The plugin surfaces it
/// as [SK2Transaction.jsonRepresentation] and, on the purchase stream, as
/// `PurchaseDetails.verificationData.localVerificationData`.
///
/// Two fields matter here and neither is exposed as a typed property by the plugin:
///   * `revocationDate` — set once Apple refunds or otherwise revokes the transaction. The
///     plugin forwards revoked transactions from `Transaction.updates` with status *purchased*,
///     so without this check a refund would re-grant the entitlement it just took away.
///   * `type` — `Consumable`, `Non-Consumable`, `Non-Renewing Subscription` or
///     `Auto-Renewable Subscription`, i.e. how the product is actually configured in App Store
///     Connect. Logged so the configuration can be confirmed from the field.
class StoreKitTransactionJson {
  static Map<String, dynamic>? _decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// True when the payload carries a `revocationDate`, i.e. the App Store has refunded or
  /// revoked this transaction and it no longer entitles the customer to anything.
  static bool isRevoked(String? json) => _decode(json)?['revocationDate'] != null;

  /// The App Store product type recorded in the payload, or null if unknown.
  static String? productType(String? json) {
    final Object? type = _decode(json)?['type'];
    return type is String ? type : null;
  }
}

/// Distils the customer's full transaction history (`Transaction.all`) down to the newest
/// un-revoked transaction for each ad-free product, expressed as *restored* [PurchaseDetails] so
/// it can be fed through the same delivery path as a store restore.
///
/// Why this exists: the plugin's `restorePurchases()` walks `Transaction.currentEntitlements`,
/// which by design never contains consumable in-app purchases. If an ad-free product is (or was)
/// configured as a consumable in App Store Connect, the customer is charged, the transaction is
/// finished, and from then on no restore can ever find it again — which is exactly what the
/// September 2026 report described. `Transaction.all` does still list it (on iOS 18+ once the
/// app opts in with `SKIncludeConsumableInAppPurchaseHistory`), along with every non-consumable
/// and subscription, so scanning it after the normal restore closes that gap. Revoked
/// transactions are filtered out, since `Transaction.all` keeps refunds that
/// `currentEntitlements` would already have dropped.
///
/// Newest-wins matters for the yearly product: someone who bought it three times and had two of
/// them refunded must have their expiry set by the purchase that still stands.
List<PurchaseDetails> adFreeRestoresFromHistory(Iterable<SK2Transaction> history) {
  final Map<String, SK2Transaction> newestPerProduct = <String, SK2Transaction>{};
  for (final SK2Transaction transaction in history) {
    if (!kAdFreeProductIds.contains(transaction.productId)) continue;
    if (StoreKitTransactionJson.isRevoked(transaction.jsonRepresentation)) continue;
    final SK2Transaction? incumbent = newestPerProduct[transaction.productId];
    if (incumbent == null || _purchaseMillis(transaction) > _purchaseMillis(incumbent)) {
      newestPerProduct[transaction.productId] = transaction;
    }
  }
  return newestPerProduct.values.map(_asRestoredPurchase).toList();
}

int _purchaseMillis(SK2Transaction transaction) => int.tryParse(transaction.purchaseDate) ?? 0;

PurchaseDetails _asRestoredPurchase(SK2Transaction transaction) {
  return PurchaseDetails(
    productID: transaction.productId,
    purchaseID: transaction.id,
    verificationData: PurchaseVerificationData(
      localVerificationData: transaction.jsonRepresentation ?? '',
      serverVerificationData: transaction.receiptData ?? '',
      source: 'app_store',
    ),
    transactionDate: transaction.purchaseDate.isEmpty ? null : transaction.purchaseDate,
    // A history-sourced transaction was finished long ago (or is a restore of one that was);
    // `restored` keeps pendingCompletePurchase false so the delivery path never tries to finish
    // it again.
    status: PurchaseStatus.restored,
  );
}
