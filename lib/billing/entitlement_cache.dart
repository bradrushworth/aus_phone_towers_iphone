import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last-known ad-free entitlement to [SharedPreferences] so a
/// paying user never sees ads at cold start, before the store has had a
/// chance to respond to `initStoreInfo()`.
///
/// This is a seed only: [PurchaseHelper._hasPurchase] always re-evaluates
/// against the store once it responds and overwrites this cache accordingly,
/// so a refunded/expired purchase still re-shows ads once the store answers.
class EntitlementCache {
  static const String _kIsSubscribed = 'cached_is_subscribed';
  static const String _kIsSubscribedPermanently = 'cached_is_subscribed_permanently';
  static const String _kYearlyExpiryEpoch = 'cached_yearly_expiry_epoch';

  /// Writes a permanent ad-free entitlement to the cache.
  static Future<void> savePermanent(SharedPreferences prefs) async {
    await prefs.setBool(_kIsSubscribed, true);
    await prefs.setBool(_kIsSubscribedPermanently, true);
    await prefs.setInt(_kYearlyExpiryEpoch, 0);
  }

  /// Writes an active yearly ad-free entitlement, expiring at [yearlyExpiryEpoch]
  /// (epoch milliseconds), to the cache.
  static Future<void> saveYearly(SharedPreferences prefs, {required int yearlyExpiryEpoch}) async {
    await prefs.setBool(_kIsSubscribed, true);
    await prefs.setBool(_kIsSubscribedPermanently, false);
    await prefs.setInt(_kYearlyExpiryEpoch, yearlyExpiryEpoch);
  }

  /// Clears any cached entitlement (no ad-free purchase currently held).
  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.setBool(_kIsSubscribed, false);
    await prefs.setBool(_kIsSubscribedPermanently, false);
    await prefs.setInt(_kYearlyExpiryEpoch, 0);
  }

  /// Reads the cached entitlement. A cached yearly entitlement only counts
  /// while [nowMillis] is before its stored expiry epoch.
  static CachedEntitlement read(SharedPreferences prefs, {required int nowMillis}) {
    final bool isSubscribedPermanently = prefs.getBool(_kIsSubscribedPermanently) ?? false;
    final int yearlyExpiryEpoch = prefs.getInt(_kYearlyExpiryEpoch) ?? 0;
    final bool cachedIsSubscribed = prefs.getBool(_kIsSubscribed) ?? false;

    if (isSubscribedPermanently) {
      return const CachedEntitlement(isSubscribed: true, isSubscribedPermanently: true);
    }

    if (cachedIsSubscribed && yearlyExpiryEpoch > 0 && nowMillis < yearlyExpiryEpoch) {
      return const CachedEntitlement(isSubscribed: true, isSubscribedPermanently: false);
    }

    return const CachedEntitlement(isSubscribed: false, isSubscribedPermanently: false);
  }
}

/// Immutable result of reading [EntitlementCache].
class CachedEntitlement {
  final bool isSubscribed;
  final bool isSubscribedPermanently;

  const CachedEntitlement({
    required this.isSubscribed,
    required this.isSubscribedPermanently,
  });
}
