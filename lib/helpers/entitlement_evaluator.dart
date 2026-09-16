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

/// The Non-Renewing Subscription replacing [skuSubscribeOneYear] (bead `aptios-589`).
///
/// `yearly_adfree` is a **Consumable** in App Store Connect: the App Store sells it again
/// every time and StoreKit 2's restore (`Transaction.currentEntitlements`) never returns it.
/// Product types cannot be changed after creation, so the fix is a new product id, typed as a
/// Non-Renewing Subscription — restorable, and re-purchasable once its year is up. Both ids
/// grant the same one-year ad-free entitlement with the same purchase-date + one-year expiry
/// math (a Non-Renewing Subscription has no server-side "current" state of its own — Apple
/// hands the transaction back like any other owned purchase and leaves expiry entirely to the
/// app, exactly as this app always computed it for the consumable). [PurchaseHelper] prefers
/// selling this id once the store returns it and falls back to [skuSubscribeOneYear] until the
/// owner creates the product in App Store Connect.
const String skuSubscribeOneYearPass = 'yearly_adfree_pass';

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

  /// Yearly ad-free product ids ([skuSubscribeOneYear] and/or [skuSubscribeOneYearPass]) that
  /// are held but have passed their one-year expiry. The caller is responsible for finishing
  /// (if still pending) and dropping each of these from its purchase inventory so the product
  /// can be sold again — see [PurchaseHelper]. Independent of [isSubscribed]: a user can hold
  /// one expired product and one still-active one (e.g. an old expired consumable and a fresh
  /// pass), in which case this still lists the expired one even though ads stay removed.
  final List<String> expiredYearlyProductIds;

  const PurchaseEntitlement({
    required this.isDonated,
    required this.isSubscribed,
    required this.isSubscribedPermanently,
    required this.hasPurchaseProcessed,
    required this.timeToExpireYearlySubscription,
    required this.yearlyPurchaseExpired,
    required this.yearlyExpiryEpoch,
    this.expiredYearlyProductIds = const <String>[],
  });
}

/// Result of evaluating a single yearly-ad-free product id against the clock.
class _YearlySkuEvaluation {
  final bool active;
  final int expiryEpoch;

  const _YearlySkuEvaluation({required this.active, required this.expiryEpoch});
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

  // 2) Yearly ad-free - either product id grants ad-free for [expiryPeriod] from its own
  // purchase date. Two ids can grant this: the legacy `yearly_adfree` consumable and its
  // Non-Renewing Subscription replacement `yearly_adfree_pass` (see [skuSubscribeOneYearPass]
  // doc comment, bead aptios-589). Evaluated independently so one can be expired while the
  // other is active (e.g. a lapsed old consumable and a freshly bought pass).
  final List<String> expiredYearlyProductIds = <String>[];
  _YearlySkuEvaluation? evaluateYearlySku(String sku) {
    PurchaseDetails? purchase;
    try {
      purchase = owned.singleWhere((p) => p.productID == sku);
    } on StateError {
      return null;
    }
    final int purchaseTime = _parseTransactionDateMillis(purchase.transactionDate) ?? 0;
    if (purchaseTime <= 0) return null;
    if (purchaseTime < nowMillis - expiryPeriod) {
      // The one year of ad-free is over.
      expiredYearlyProductIds.add(sku);
      return const _YearlySkuEvaluation(active: false, expiryEpoch: 0);
    }
    return _YearlySkuEvaluation(active: true, expiryEpoch: purchaseTime + expiryPeriod);
  }

  final _YearlySkuEvaluation? passEval = evaluateYearlySku(skuSubscribeOneYearPass);
  final _YearlySkuEvaluation? legacyEval = evaluateYearlySku(skuSubscribeOneYear);

  // Prefer whichever is active and expires later, so a customer holding both (say, a lapsing
  // legacy consumable and a freshly bought pass) always sees the longer-lived expiry.
  _YearlySkuEvaluation? winner;
  if (passEval?.active == true && legacyEval?.active == true) {
    winner = passEval!.expiryEpoch >= legacyEval!.expiryEpoch ? passEval : legacyEval;
  } else if (passEval?.active == true) {
    winner = passEval;
  } else if (legacyEval?.active == true) {
    winner = legacyEval;
  }

  final bool yearlyActive = winner != null;
  final bool yearlyExpired = winner == null && expiredYearlyProductIds.isNotEmpty;
  String timeToExpire = '';
  int yearlyExpiryEpoch = 0;
  if (winner != null) {
    yearlyExpiryEpoch = winner.expiryEpoch;
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(yearlyExpiryEpoch);
    await initializeDateFormatting('en-AU', null);
    timeToExpire = 'Expires ${DateFormat.yMMMd('en-AU').format(date)}';
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
    expiredYearlyProductIds: expiredYearlyProductIds,
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
