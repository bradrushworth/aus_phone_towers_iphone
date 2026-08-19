import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Product identifiers for the store entitlements.
///
/// These mirror the constants defined in [PurchaseHelper] so the pure decision
/// logic can be unit tested without pulling in StoreKit / AdMob / Firebase.
const String skuDonationSmall = 'donation_small';
const String skuDonationMedium = 'donation_medium';
const String skuDonationLarge = 'donation_large';
const String skuSubscribePermanently = 'permanent_adfree';
const String skuSubscribeOneYear = 'yearly_adfree';

/// Immutable result of evaluating the user's store entitlements.
///
/// This is the single source of truth for the ad-display / subscription
/// decision used by PurchaseHelper. Keeping it pure (no StoreKit, no analytics,
/// no UI side effects) lets the core logic be unit tested deterministically with
/// injected purchases and a controllable clock.
class PurchaseEntitlement {
  final bool isDonated;
  final bool isSubscribed;
  final bool isSubscribedPermanently;
  final bool hasPurchaseProcessed;
  final String timeToExpireYearlySubscription;
  final bool yearlyPurchaseExpired;

  /// Epoch milliseconds when the yearly subscription expires, or 0 if not active.
  final int yearlyExpiryEpoch;

  const PurchaseEntitlement({
    required this.isDonated,
    required this.isSubscribed,
    required this.isSubscribedPermanently,
    required this.hasPurchaseProcessed,
    required this.timeToExpireYearlySubscription,
    required this.yearlyPurchaseExpired,
    required this.yearlyExpiryEpoch,
  });
}

/// Pure, side-effect-free evaluation of ad-free entitlements.
///
/// Mirrors the decision logic that previously lived inside
/// `PurchaseHelper._hasPurchase`:
///   * Any donation tier sets [PurchaseEntitlement.isDonated] but does **not**
///     remove ads.
///   * A `yearly_adfree` purchase grants ad-free for [expiryPeriod] milliseconds
///     from its [PurchaseDetails.transactionDate]. Once expired,
///     [PurchaseEntitlement.yearlyPurchaseExpired] is true (the caller is
///     responsible for finishing/consuming the transaction).
///   * A `permanent_adfree` purchase grants ad-free forever.
///
/// [nowMillis] is injected so tests can use a fixed clock and stay non-flaky.
Future<PurchaseEntitlement> evaluateEntitlements(
  List<PurchaseDetails?> purchases, {
  required int nowMillis,
  required int expiryPeriod,
}) async {
  final List<PurchaseDetails> owned =
      purchases.whereType<PurchaseDetails>().toList();

  // 1) Donation (any tier) - does NOT remove ads.
  final bool isDonated = owned.any((PurchaseDetails p) =>
      p.productID == skuDonationSmall ||
      p.productID == skuDonationMedium ||
      p.productID == skuDonationLarge);

  // 2) Yearly subscription - non-consumable, ad-free for [expiryPeriod] only.
  PurchaseDetails? oneYear;
  try {
    oneYear = owned.singleWhere((p) => p.productID == skuSubscribeOneYear);
  } on StateError {
    oneYear = null;
  }
  bool yearlyActive = false;
  bool yearlyExpired = false;
  String timeToExpire = '';
  int yearlyExpiryEpoch = 0;
  if (oneYear != null) {
    final int purchaseTime = _parseTransactionDateMillis(oneYear.transactionDate) ?? 0;
    if (purchaseTime > 0) {
      if (purchaseTime < nowMillis - expiryPeriod) {
        // The one year of ad-free is over.
        yearlyExpired = true;
      } else {
        yearlyActive = true;
        yearlyExpiryEpoch = purchaseTime + expiryPeriod;
        final DateTime date =
            DateTime.fromMillisecondsSinceEpoch(yearlyExpiryEpoch);
        await initializeDateFormatting('en-AU', null);
        timeToExpire =
            'Expires ${DateFormat.yMMMd('en-AU').format(date)}';
      }
    }
  }

  // 3) Permanent subscription - ad-free forever.
  PurchaseDetails? permanent;
  try {
    permanent = owned.singleWhere((p) => p.productID == skuSubscribePermanently);
  } on StateError {
    permanent = null;
  }
  final bool permanentSub = permanent != null;
  final bool subscription = permanentSub || yearlyActive;

  return PurchaseEntitlement(
    isDonated: isDonated,
    isSubscribed: subscription,
    isSubscribedPermanently: permanentSub,
    hasPurchaseProcessed: true,
    timeToExpireYearlySubscription: timeToExpire,
    yearlyPurchaseExpired: yearlyExpired,
    yearlyExpiryEpoch: yearlyExpiryEpoch,
  );
}

/// Parses [PurchaseDetails.transactionDate] into epoch milliseconds.
///
/// The format varies by platform/plugin path:
///   * Android and iOS StoreKit1 report epoch milliseconds as a string.
///   * iOS StoreKit2 (the `in_app_purchase_storekit` default since 0.4.x) reports epoch
///     milliseconds too as of 0.4.11+1 — but 0.4.10.x reported a `"yyyy-MM-dd HH:mm:ss"`
///     local-time string instead, which silently fails `int.tryParse` and left yearly
///     purchases on iOS permanently unrecognised (ads never removed). Both formats are
///     handled here so this keeps working regardless of platform or plugin version.
int? _parseTransactionDateMillis(String? transactionDate) {
  if (transactionDate == null || transactionDate.isEmpty) return null;
  final int? epochMillis = int.tryParse(transactionDate);
  if (epochMillis != null) return epochMillis;
  try {
    return DateTime.parse(transactionDate).millisecondsSinceEpoch;
  } on FormatException {
    return null;
  }
}
