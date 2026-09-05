import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart' show SK2Transaction;
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/billing/consumable_store.dart';
import 'package:phonetowers/billing/entitlement_cache.dart';
import 'package:phonetowers/billing/restore_outcome.dart';
import 'package:phonetowers/billing/transaction_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/strings.dart';
import 'analytics_helper.dart';
import 'entitlement_evaluator.dart';
import 'price_label_helper.dart';

typedef void ShowSnackBar({
  required String message,
  Duration duration,
  bool isDismissible,
});

class PurchaseHelper with ChangeNotifier {
  static final PurchaseHelper _singleton = new PurchaseHelper._internal();

  factory PurchaseHelper() {
    return _singleton;
  }

  PurchaseHelper._internal();

  Logger logger = Logger();

  /// Is the API available on the device
  bool available = false;

  /// `late` so merely constructing the singleton (e.g. in widget tests that
  /// only read entitlement flags) doesn't touch `InAppPurchase.instance`,
  /// whose platform registration opens a billing platform channel and fails
  /// asynchronously in tests where no channel handler exists.
  late final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  // ignore: unused_field
  List<String> _notFoundIds = [];
  List<ProductDetails?> _products = [];
  List<PurchaseDetails?> _purchases = [];
  // ignore: unused_field
  List<String> _consumables = [];
  // ignore: unused_field
  bool _isAvailable = false;
  // ignore: unused_field
  bool _purchasePending = false;
  // ignore: unused_field
  bool _loading = true;
  // ignore: unused_field
  String? _queryProductError;


  static const String SKU_DONATION_SMALL = "donation_small";
  static const String SKU_DONATION_MEDIUM = "donation_medium";
  static const String SKU_DONATION_LARGE = "donation_large";
  static const String SKU_SUBSCRIBE_PERMANENTLY = "permanent_adfree";
  static const String SKU_SUBSCRIBE_ONE_YEAR = "yearly_adfree";

  final Set<String> _kProductIds = Set.from([
    SKU_DONATION_SMALL,
    SKU_DONATION_MEDIUM,
    SKU_DONATION_LARGE,
    SKU_SUBSCRIBE_ONE_YEAR,
    SKU_SUBSCRIBE_PERMANENTLY,
  ]);

  bool isDonated = false;
  bool isSubscribed = false;
  bool isSubscribedPermanently = false;
  String timeToExpireYearlySubscription = '';

  bool isDonateSmallPurchased = false;
  bool isDonateMediumPurchased = false;
  bool isDonateLargePurchased = false;

  final int EXPIRY_PERIOD = 365 * 24 * 60 * 60 * 1000;

  late ShowSnackBar showSnackBar;

  bool hasPurchaseProcessed = false;

  /// Test seams for [restorePurchases] — see test/helpers/purchase_helper_restore_test.dart.
  /// [debugStoreRestore] stands in for the plugin's own restore; [debugTransactionHistory] for
  /// the StoreKit 2 `Transaction.all` read (and forces that scan on, whatever the host platform).
  @visibleForTesting
  Future<void> Function()? debugStoreRestore;
  @visibleForTesting
  Future<List<SK2Transaction>> Function()? debugTransactionHistory;

  /// How long [restorePurchases] waits for the plugin to deliver the restored transactions on
  /// the purchase stream before concluding there were none. StoreKit 2 answers from its local
  /// cache in well under a second; the margin covers a slow device, not the network.
  @visibleForTesting
  Duration restoreBatchTimeout = const Duration(seconds: 3);

  /// Completes once the batch of restored transactions for the in-flight restore has been
  /// processed (or an empty "nothing to restore" batch has arrived).
  Completer<void>? _restoreBatch;

  /// Whether the in-flight restore delivered at least one restored transaction, by either path.
  bool _restoreDelivered = false;

  /// Seeds [isSubscribed]/[isSubscribedPermanently] from the locally cached
  /// entitlement (see [EntitlementCache]) so a paying user doesn't see ads at
  /// cold start while the store is still being queried. Call this before/
  /// alongside [initStoreInfo] at app startup.
  ///
  /// This is a seed only — the next successful [_hasPurchase] evaluation
  /// (triggered by [initStoreInfo]'s store round-trip) always overwrites both
  /// these flags and the cache itself, so a refunded/expired purchase still
  /// re-shows ads once the store responds.
  Future<void> loadCachedEntitlement({int? nowMillis}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final CachedEntitlement cached = EntitlementCache.read(
      prefs,
      nowMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
    );
    isSubscribed = cached.isSubscribed;
    isSubscribedPermanently = cached.isSubscribedPermanently;
    notifyListeners();
  }

  void initStoreInfo({required ShowSnackBar showSnackBar}) async {
    this.showSnackBar = showSnackBar;

    // Listen to new purchases immediately
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription!.cancel();

        String error = 'PurchaseHelper.onDone';
        logger.i(error);
        showSnackBar(message: error);
      },
      onError: (error) {
        // handle error here.
        logger.e('Error in PurchaseHelper.purchaseUpdated: Error is $error');
        AnalyticsHelper().log(error);
        showSnackBar(message: error.toString());
      },
    );

    // Check availability of In App Purchases
    final available = await _inAppPurchase.isAvailable();

    // Report statistics to Firebase
    AnalyticsHelper().sendCustomAnalyticsEvent(
      eventName: 'setup_billing',
      eventParameters: <String, Object>{
        'message': available
            ? 'The Payment platform is ready and available'
            : 'The Payment platform is not ready and available',
      },
    );
    // showSnackBar(
    //   message: available
    //       ? 'The Payment platform is ready and available'
    //       : 'The Payment platform is NOT ready and available',
    // );

    if (available) {
      // Independent round-trips, so run them together: restorePurchases() now waits briefly for
      // the store's answer, and the prices must not queue behind that wait.
      await Future.wait<void>(<Future<void>>[restorePurchases(), _getProducts()]);
    } else {
      // Oh no, there was a problem.
      String error = 'The Payment platform is not ready and available';
      logger.e('Error in PurchaseHelper: Error is $error');
      AnalyticsHelper().log(error);
      showSnackBar(message: error);

      _products = [];
      _purchases = [];
      _notFoundIds = [];
      _consumables = [];
      _purchasePending = false;
      _loading = false;
      return;
    }
  }

  /// Restore all purchases from the store, then reconcile the entitlement against the answer.
  ///
  /// Pass [userInitiated] true when called from the "Restore Purchases" row in Settings. That
  /// first asks StoreKit to sync with the App Store — Apple's prescribed restore, which may show
  /// a sign-in sheet, fine for an explicit tap but not for a cold start — and reports the outcome
  /// in a snackbar once the answer is actually in.
  ///
  /// The plugin delivers restored transactions asynchronously on the purchase stream, usually a
  /// beat after its own future completes, so this waits for that batch (bounded by
  /// [restoreBatchTimeout]) before reading [isSubscribed]. The earlier version reported whatever
  /// the flags said at that instant, which for a slow answer was "no purchase found" over the top
  /// of a purchase that arrived a moment later.
  ///
  /// Two things then happen that the store's own restore does not do by itself:
  ///   1. The StoreKit 2 transaction history is scanned for ad-free purchases the restore missed
  ///      — see [adFreeRestoresFromHistory] for why a consumable-typed product is invisible to it.
  ///   2. If nothing at all was restored and both answers were authoritative, the entitlement is
  ///      re-evaluated against what this session already holds, so a cached entitlement whose
  ///      purchase has since been refunded (or belongs to another Apple ID) is dropped instead of
  ///      granting ad-free forever. A failure on either path leaves the cache alone: no answer is
  ///      not the same as "no purchase".
  Future<void> restorePurchases({bool userInitiated = false}) async {
    if (userInitiated) {
      showSnackBar(
        message: 'Checking the App Store for your purchases…',
        duration: const Duration(seconds: 3),
      );
      await _syncWithAppStore();
    }

    _restoreDelivered = false;
    final Completer<void> batch = Completer<void>();
    _restoreBatch = batch;
    try {
      if (debugStoreRestore != null) {
        await debugStoreRestore!();
      } else {
        await _inAppPurchase.restorePurchases();
      }
    } catch (error) {
      _restoreBatch = null;
      String message = 'Failed to restore purchases: $error';
      logger.e('PurchaseHelper: $message');
      AnalyticsHelper().log(message);
      showSnackBar(message: message, duration: const Duration(seconds: 5), isDismissible: true);
      return;
    }
    await batch.future.timeout(restoreBatchTimeout, onTimeout: () {});
    _restoreBatch = null;

    final bool historyOk = await _restoreAdFreeFromTransactionHistory();
    if (historyOk && !_restoreDelivered) {
      await _hasPurchase();
    }

    if (userInitiated) {
      showSnackBar(
        message: restoreOutcomeMessage(isSubscribed: isSubscribed),
        duration: const Duration(seconds: 5),
        isDismissible: true,
      );
    }
  }

  /// `AppStore.sync()` — refreshes StoreKit's local transaction cache from the App Store, which is
  /// what makes a restore after a reinstall, or on a device the purchase was never made on, find
  /// anything. It can prompt for the Apple ID password, so it is reserved for an explicit tap.
  Future<void> _syncWithAppStore() async {
    if (kIsWeb || !Platform.isIOS || !InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) return;
    try {
      await _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>().sync();
    } catch (error) {
      // Declining the sign-in sheet or having no network is not fatal: the restore below still
      // consults whatever StoreKit already holds locally.
      logger.w('PurchaseHelper: AppStore.sync failed: $error');
      AnalyticsHelper().log('AppStore.sync failed: $error');
    }
  }

  /// Scans the full StoreKit 2 transaction history for ad-free purchases that the plugin's
  /// restore (which only walks `Transaction.currentEntitlements`) cannot see, and delivers them
  /// through the normal restore path.
  ///
  /// Returns whether the combined answer is *authoritative* — i.e. an empty result really means
  /// "no purchase" and the caller may drop a cached entitlement on the strength of it. It is not
  /// when the history could not be read, and not on iOS below 18, where a finished consumable
  /// (which is what "One Year Ad Free" is in App Store Connect) appears in no StoreKit list at
  /// all: there the cache is the only record of the pass and has to be left alone.
  Future<bool> _restoreAdFreeFromTransactionHistory() async {
    final bool injected = debugTransactionHistory != null;
    Future<List<SK2Transaction>> Function()? fetchHistory = debugTransactionHistory;
    if (fetchHistory == null) {
      if (kIsWeb || !Platform.isIOS || !InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) {
        return true; // Nothing further to consult on this platform; the store's answer stands.
      }
      fetchHistory = SK2Transaction.transactions;
    }
    List<SK2Transaction> history;
    try {
      history = await fetchHistory();
    } catch (error) {
      logger.e('PurchaseHelper: could not read the StoreKit transaction history: $error');
      AnalyticsHelper().log('StoreKit transaction history read failed: $error');
      return false;
    }
    _reportTransactionHistory(history);
    final List<PurchaseDetails> restores = adFreeRestoresFromHistory(history);
    if (restores.isNotEmpty) {
      await _listenToPurchaseUpdated(restores);
    }
    return injected || _historyIncludesConsumables();
  }

  /// True once `Transaction.all` can be trusted to list finished consumables: iOS 18 and later,
  /// with `SKIncludeConsumableInAppPurchaseHistory` set in Info.plist (it is).
  static bool _historyIncludesConsumables() {
    // e.g. "Version 18.1 (Build 22B83)"
    final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    final int major = int.tryParse(match?.group(1) ?? '') ?? 0;
    return major >= 18;
  }

  /// Answers, from the field, how the ad-free products are actually configured in App Store
  /// Connect: each transaction payload records the product `type`. A `Consumable` here is the
  /// smoking gun for "restore never finds my purchase" — see [adFreeRestoresFromHistory].
  void _reportTransactionHistory(List<SK2Transaction> history) {
    final List<String> adFree = history
        .where((SK2Transaction t) => kAdFreeProductIds.contains(t.productId))
        .map((SK2Transaction t) =>
            '${t.productId}:${StoreKitTransactionJson.productType(t.jsonRepresentation) ?? '?'}'
            '${StoreKitTransactionJson.isRevoked(t.jsonRepresentation) ? ':revoked' : ''}')
        .toList();
    logger.i(
        'PurchaseHelper: transaction history holds ${history.length} transactions; ad-free: $adFree');
    // Firebase caps a parameter value at 100 characters.
    final String summary = adFree.join(',');
    AnalyticsHelper().sendCustomAnalyticsEvent(
      eventName: 'transaction_history',
      eventParameters: <String, Object>{
        'count': history.length,
        'ad_free': summary.length > 100 ? summary.substring(0, 100) : summary,
      },
    );
  }

  /// Test-only seam for injecting fake product details without a real store connection — see
  /// test/ui/widgets/support_prompt_screen_test.dart.
  @visibleForTesting
  set debugProducts(List<ProductDetails?> products) => _products = products;

  /// Test-only seam for resetting/injecting the in-memory purchase list —
  /// PurchaseHelper is a singleton, so tests that call deliverProduct/_hasPurchase
  /// must be able to reset this between cases to avoid leaking state.
  @visibleForTesting
  set debugPurchases(List<PurchaseDetails?> purchases) => _purchases = purchases;

  /// The store's localized price string for [sku] (e.g. "$5.99", "A$5.99", "€5.49" — already
  /// formatted for the user's storefront/locale), or null if product details haven't loaded
  /// yet (the store query is still in flight, failed, or [sku] is unknown).
  String? priceFor(String sku) => PriceLabelHelper.findPrice(_products, sku);

  /// Builds a menu/screen label combining [name] with the live store price for [sku], falling
  /// back to [fallback] (typically a hardcoded "Name ($X.XX)" string) while pricing hasn't
  /// loaded yet, so menus never show a broken/blank price.
  String priceLabel({required String sku, required String name, String? fallback}) =>
      PriceLabelHelper.buildLabel(products: _products, sku: sku, name: name, fallback: fallback);

  /// Get all products available for sale
  Future<void> _getProducts() async {
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    final ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(
      _kProductIds.toSet(),
    );
    if (productDetailResponse.error != null) {
      String error = "In-App Billing Failed: " + productDetailResponse.error!.message;
      showSnackBar(message: error);
      logger.e("PurchaseHelper: " + error);
      AnalyticsHelper().log(error);

      _queryProductError = productDetailResponse.error!.message;
      _products = productDetailResponse.productDetails;
      // Deliberately not touching _purchases: a failed *product* query says nothing about what
      // the customer owns, and wiping the list here used to let the same ad-free SKU be sold
      // again after a flaky price fetch.
      _notFoundIds = productDetailResponse.notFoundIDs;
      _consumables = [];
      _purchasePending = false;
      _loading = false;
      return;
    }

    // if (!kIsWeb && Platform.isAndroid) {
    //   // For testing purposes
    //   List<ProductDetails> _products = [];
    //   _products.add(ProductDetails(
    //       id: SKU_SUBSCRIBE_ONE_YEAR,
    //       title: 'One Year Ad Free',
    //       description: 'This removes all ads from app for one year.',
    //       price: '\$14.99',
    //       rawPrice: 14.99,
    //       currencyCode: 'AUD'));
    //   _products.add(ProductDetails(
    //       id: SKU_SUBSCRIBE_PERMANENTLY,
    //       title: 'Permanent Ad Free',
    //       description: 'This removes all ads from app permanently.',
    //       price: '\24.99',
    //       rawPrice: 24.99,
    //       currencyCode: 'AUD'));
    //   _products.add(ProductDetails(
    //       id: SKU_DONATION_SMALL,
    //       title: 'Morning Coffee',
    //       description: 'I am very appreciative for a coffee. Thanks!',
    //       price: '\$5.99',
    //       rawPrice: 5.99,
    //       currencyCode: 'AUD'));
    //   _products.add(ProductDetails(
    //       id: SKU_DONATION_MEDIUM,
    //       title: 'Coffee and Cake',
    //       description: 'Coffee and cake! I\'m getting a sugar fix...',
    //       price: '\$14.99',
    //       rawPrice: 14.99,
    //       currencyCode: 'AUD'));
    //   _products.add(ProductDetails(
    //       id: SKU_DONATION_LARGE,
    //       title: 'Thanks For Lunch',
    //       description: 'You\'re awesome! Thanks for lunch :-)',
    //       price: '\$14.99',
    //       rawPrice: 14.99,
    //       currencyCode: 'AUD'));
    //
    //   List<String> consumables = await ConsumableStore.load();
    //   _notFoundIds = productDetailResponse.notFoundIDs;
    //   _consumables = consumables;
    //   _purchasePending = false;
    //   _loading = false;
    //   if (_products.isNotEmpty) {
    //     String error = "Faking Google Store!";
    //     //showSnackBar(message: error);
    //     logger.i("PurchaseHelper: " + error);
    //   } else {
    //     String error = "Faking Google Store didn't work!";
    //     //showSnackBar(message: error);
    //     logger.e("PurchaseHelper: " + error);
    //   }
    //   return;
    // }

    if (productDetailResponse.productDetails.isEmpty) {
      String error = "In-App Billing is empty!";
      showSnackBar(message: error);
      logger.e("PurchaseHelper: " + error);
      AnalyticsHelper().log(error);

      _queryProductError = null;
      _products = productDetailResponse.productDetails;
      _notFoundIds = productDetailResponse.notFoundIDs;
      _consumables = [];
      _purchasePending = false;
      _loading = false;
      return;
    }

    List<String> consumables = await ConsumableStore.load();
    // A SKU the storefront does not recognise is the single most likely reason a price goes
    // missing from the menu (the label then shows the bare product name). It used to be swallowed
    // here, so a product id that had drifted from App Store Connect looked identical to a slow
    // network. Report it.
    if (productDetailResponse.notFoundIDs.isNotEmpty) {
      final String error =
          'Store does not know these product ids: ${productDetailResponse.notFoundIDs.join(', ')}';
      logger.e('PurchaseHelper: ' + error);
      AnalyticsHelper().log(error);
      AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'products_not_found',
        eventParameters: <String, Object>{'ids': productDetailResponse.notFoundIDs.join(',')},
      );
    }
    _products = productDetailResponse.productDetails;
    _notFoundIds = productDetailResponse.notFoundIDs;
    _consumables = consumables;
    _purchasePending = false;
    _loading = false;
    String error = "In-App Billing is completed!";
    //showSnackBar(message: error);
    logger.i("PurchaseHelper: " + error);

    // Record how App Store Connect actually types each product. The ad-free products must be
    // non-consumable (or a subscription) for a restore to ever find them again; a consumable
    // here can be bought repeatedly and is gone from the store's view the moment it's finished.
    final List<String> types = _products
        .whereType<AppStoreProduct2Details>()
        .map((AppStoreProduct2Details p) => '${p.id}:${p.sk2Product.type.name}')
        .toList();
    if (types.isNotEmpty) {
      logger.i('PurchaseHelper: store product types: $types');
      AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'products_loaded',
        eventParameters: <String, Object>{'types': types.join(',')},
      );
    }

    // Let any already-open UI (e.g. SupportPromptScreen) pick up live store pricing —
    // see priceFor/priceLabel — without needing an unrelated purchase event to fire.
    notifyListeners();
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      iosPlatformAddition.setDelegate(null);
    }

    if (_subscription != null) {
      _subscription!.cancel();
    }

    super.dispose();
  }

  /// Gets past purchases
  Future<void> _hasPurchase() async {
    Map<String, PurchaseDetails> purchases = Map.fromEntries(
      _purchases.map((PurchaseDetails? purchase) {
        if (purchase!.pendingCompletePurchase) {
          // Expected for a purchase that is still being delivered — _listenToPurchaseUpdated
          // finishes it once delivery returns. This used to be a snackbar aimed at real users.
          logger.d('_hasPurchase: ${purchase.productID} is awaiting completePurchase');
        }
        return MapEntry<String, PurchaseDetails>(purchase.productID, purchase);
      }),
    );
    _purchases = purchases.values.toList();

    Map<String, Object> eventMap = Map<String, Object>();

    // Delegate the pure decision logic (donation / yearly expiry / permanent) to
    // a testable, side-effect-free evaluator. The evaluator is deterministic given
    // the injected purchases and clock, so this method retains only the side
    // effects (finishing an expired yearly purchase, analytics, UI signal).
    final PurchaseEntitlement entitlement = await evaluateEntitlements(
      _purchases,
      nowMillis: DateTime.now().millisecondsSinceEpoch,
      expiryPeriod: EXPIRY_PERIOD,
    );

    // 2a) Finish/consume an expired yearly purchase so ads return and the user
    // can buy it again. (evaluateEntitlements is pure, so the mutation lives here.)
    if (entitlement.yearlyPurchaseExpired) {
      PurchaseDetails? expired;
      try {
        expired = _purchases.singleWhere(
            (purchaseDetails) => purchaseDetails!.productID == SKU_SUBSCRIBE_ONE_YEAR);
      } catch (e) {
        expired = null;
      }
      if (expired != null) {
        eventMap['expired_sku'] = SKU_SUBSCRIBE_ONE_YEAR;
        if (expired.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(expired);
        }
        _purchases.removeWhere((p) => p!.productID == SKU_SUBSCRIBE_ONE_YEAR);
      }
    }

    // Apply the computed entitlement state.
    isDonated = entitlement.isDonated;
    isSubscribed = entitlement.isSubscribed;
    isSubscribedPermanently = entitlement.isSubscribedPermanently;
    timeToExpireYearlySubscription = entitlement.timeToExpireYearlySubscription;

    final bool yearly = entitlement.isSubscribed && !entitlement.isSubscribedPermanently;
    eventMap['donation'] = entitlement.isDonated;
    eventMap['permanent'] = entitlement.isSubscribedPermanently;
    eventMap['yearly'] = yearly;
    eventMap['subscription'] = entitlement.isSubscribed;
    List<String> listAllOwnedSkus = _purchases
        .whereType<PurchaseDetails>()
        .map((purchaseDetails) => purchaseDetails.productID)
        .toList();
    eventMap['owned_sku'] = listAllOwnedSkus.toString();
    if (yearly) {
      eventMap['yearly_expiry'] = entitlement.yearlyExpiryEpoch;
    }

    // Persist the freshly evaluated entitlement so a cold start before the
    // next store round-trip still knows this device is ad-free (see
    // EntitlementCache / loadCachedEntitlement). This always overwrites any
    // previously cached value, so a refund/expiry correctly clears it.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (entitlement.isSubscribedPermanently) {
      await EntitlementCache.savePermanent(prefs);
    } else if (entitlement.isSubscribed) {
      await EntitlementCache.saveYearly(prefs, yearlyExpiryEpoch: entitlement.yearlyExpiryEpoch);
    } else {
      await EntitlementCache.clear(prefs);
    }

    // Remove or display the ads
    hasPurchaseProcessed = true;
    notifyListeners();

    // Debug-only inventory dump. These were snackbars ("_hasPurchase: 3", "purchased item is
    // donation_small") fired at real users on every entitlement evaluation.
    logger.d('PurchaseHelper: _hasPurchase: ${listAllOwnedSkus.length} owned SKUs');
    for (PurchaseDetails? purchase in _purchases) {
      logger.d('purchased item is ${purchase!.productID}');
    }

    AnalyticsHelper().sendCustomAnalyticsEvent(
      eventName: 'has_purchase',
      eventParameters: eventMap,
    );
  }

  Future<void> initiatePurchase({required String sku}) async {
    logger.i('Trying to purchase: ${sku}');

    _products.forEach((product) {
      logger.w('products in inventory: ${product!.title}');
    });

    // Never sell ad-free to someone who already has it. The screens hide these buttons once
    // the entitlement is known, but the weekly Support prompt can open before the store has
    // answered at cold start — and if the product is typed as a consumable in App Store Connect
    // the customer is simply charged again in full, which is how one came to pay three times.
    // Upgrading an active yearly pass to permanent is still allowed.
    final bool alreadyHeld = (sku == SKU_SUBSCRIBE_PERMANENTLY && isSubscribedPermanently) ||
        (sku == SKU_SUBSCRIBE_ONE_YEAR && isSubscribed);
    // Likewise if the store has already told us this account owns the exact ad-free SKU.
    // Donations are consumables and are meant to be bought again, so they are never blocked.
    final bool ownedPerStore =
        kAdFreeProductIds.contains(sku) && _purchases.any((p) => p!.productID == sku);
    if (alreadyHeld || ownedPerStore) {
      logger.i('PurchaseHelper: refusing to sell $sku again (held=$alreadyHeld, owned=$ownedPerStore)');
      showSnackBar(
        message: 'You already have ads removed on this App Store account. If ads are still '
            'showing, tap ${Strings.restore_purchases} in Settings.',
        duration: const Duration(seconds: 6),
        isDismissible: true,
      );
      return;
    }

    if (_products.isNotEmpty) {
      ProductDetails? productToBuy = null;
      try {
        productToBuy = _products.singleWhere((product) {
          return product!.id == sku;
        });
      } catch (e) {
        String error = "Couldn't find the product: ${sku}";
        logger.e(error);
        showSnackBar(message: error);
      }

        if (productToBuy != null) {
          //showSnackBar(message: 'Trying to purchase ${sku} as ${productToBuy.id} ${productToBuy.title}');
          final PurchaseParam purchaseParam = PurchaseParam(productDetails: productToBuy);
          //showSnackBar(message: 'About to buy: productDetails=${purchaseParam.productDetails.title}');
          bool bought = false;
          try {
            if (productToBuy.id == SKU_SUBSCRIBE_PERMANENTLY ||
                productToBuy.id == SKU_SUBSCRIBE_ONE_YEAR) {
              // Ad-free purchases are bought as non-consumables so that, on Android, they are
              // acknowledged but never consumed (matching the Java app). On iOS this call makes
              // no difference: whether the App Store treats the product as consumable or
              // non-consumable is fixed by its type in App Store Connect, and only a
              // non-consumable (or subscription) is ever returned by a restore.
              bought = await _inAppPurchase.buyNonConsumable(
                purchaseParam: purchaseParam,
              );
            } else {
              bought = await _inAppPurchase.buyConsumable(
                purchaseParam: purchaseParam,
                autoConsume: false,
              );
            }
          } catch (error) {
            // e.g. StoreKit 2 refusing while an earlier transaction for the same product is
            // still unfinished. Left uncaught this escaped the button tap with no feedback.
            final String message = 'Purchase could not be started: $error';
            logger.e('PurchaseHelper: $message');
            AnalyticsHelper().log(message);
            showSnackBar(
              message: 'The store could not start that purchase. Please try again later.',
              duration: const Duration(seconds: 5),
              isDismissible: true,
            );
            return;
          }
          // No snackbar on the way in: buyConsumable/buyNonConsumable returning true only means
          // the request reached the store, and the store's own sheet is about to appear over the
          // top of it. The outcome is reported from _listenToPurchaseUpdated instead.
          logger.i(
              'PurchaseHelper: requested purchase (accepted=$bought) of ${purchaseParam.productDetails.id}');
          if (!bought) {
            showSnackBar(message: 'The store could not start that purchase. Please try again.');
          }
      } else {
        String error =
            'The product being bought does not match the inventory... _products = ${_products.length}';
        logger.e("PurchaseHelper: " + error);
        showSnackBar(message: error);
        _products.forEach((product) {
          logger.e('products in inventory: ${product!.title}');
        });
      }
    } else {
      String error = 'No products in inventory found...';
      showSnackBar(message: error);
      logger.e("PurchaseHelper: " + error);
      Map<String, Object> eventMap = Map<String, Object>();
      eventMap['failure'] = error;
      AnalyticsHelper().log(error);

      AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'purchase_error',
        eventParameters: eventMap,
      );
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
    // IMPORTANT!! Always verify a purchase before delivering the product.
    // For the purpose of an example, we directly return true.
    return Future<bool>.value(true);
  }

  /// Test seam for the purchase stream — see test/helpers/purchase_helper_restore_test.dart.
  @visibleForTesting
  Future<void> handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) =>
      _listenToPurchaseUpdated(purchaseDetailsList);

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    bool restoredAny = false;
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      Map<String, Object> eventMap = Map<String, Object>();
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // No snackbar: the store's own sheet is on screen and is already telling the user what
        // is happening. Announcing 'Purchase status is PurchaseStatus.pending' over the top of
        // it said nothing a user could act on.
        logger.w('Purchase status is ${purchaseDetails.status}');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // Backing out of the store sheet is a normal, deliberate act and needs no announcement.
        // This branch used to be missing entirely, so a cancel fell through to the catch-all
        // below and left the UI showing an empty snackbar — a blue bar with no text in it.
        logger.i('PurchaseHelper: purchase of ${purchaseDetails.productID} was cancelled');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          String error = 'Failed purchase of ${purchaseDetails.productID} ${purchaseDetails.purchaseID} ${purchaseDetails.error} ${purchaseDetails.transactionDate} ${purchaseDetails.verificationData} ${purchaseDetails.pendingCompletePurchase} ';
          // The user gets the store's own message where there is one; the full dump above stays
          // in the log and analytics, where it is of some use.
          final String? storeMessage = purchaseDetails.error?.message;
          showSnackBar(
              message: (storeMessage != null && storeMessage.trim().isNotEmpty)
                  ? 'Purchase failed: $storeMessage'
                  : 'That purchase could not be completed.');
          logger.e("PurchaseHelper: " + error);
          eventMap['failure'] = error;
          AnalyticsHelper().log(error);

          AnalyticsHelper().sendCustomAnalyticsEvent(
            eventName: 'purchase_error',
            eventParameters: eventMap,
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          if (purchaseDetails.status == PurchaseStatus.restored) restoredAny = true;
          // deliverProduct() below says something the user actually cares about ("Thanks so much
          // for the coffee") — this raw status line only got in its way.
          logger.i('Purchase status is ${purchaseDetails.status}');
          if (StoreKitTransactionJson.isRevoked(
              purchaseDetails.verificationData.localVerificationData)) {
            // StoreKit 2 announces a refund by re-emitting the transaction with a
            // revocationDate — and the plugin forwards it with status "purchased". Delivering it
            // would re-grant the very entitlement Apple just withdrew.
            await _withdrawRevokedPurchase(purchaseDetails);
          } else {
            bool valid = await _verifyPurchase(purchaseDetails);
            if (valid) {
              await deliverProduct(purchaseDetails, eventMap);
            } else {
              _handleInvalidPurchase(purchaseDetails);
            }
          }
        }
        // Always finish the transaction so it leaves the payment queue.
        // On iOS/StoreKit this is mandatory; on Android it is required for
        // consumables purchased with autoConsume: false (our donations).
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }

    if (restoredAny) _restoreDelivered = true;
    // Let a waiting restorePurchases() know its answer has been processed. An empty batch is
    // StoreKit 1's (and Android's) way of saying "nothing to restore".
    final Completer<void>? batch = _restoreBatch;
    if (batch != null && !batch.isCompleted && (restoredAny || purchaseDetailsList.isEmpty)) {
      batch.complete();
    }
  }

  /// Drops a refunded/revoked transaction from the inventory and re-evaluates the entitlement.
  /// Only the matching transaction goes: a yearly pass bought more than once keeps the copy that
  /// still stands (the next restore re-reads the history to be sure).
  Future<void> _withdrawRevokedPurchase(PurchaseDetails revoked) async {
    logger.w(
        'PurchaseHelper: ${revoked.productID} (${revoked.purchaseID}) has been revoked by the store');
    AnalyticsHelper().sendCustomAnalyticsEvent(
      eventName: 'purchase_revoked',
      eventParameters: <String, Object>{'sku': revoked.productID},
    );
    _purchases.removeWhere((PurchaseDetails? held) =>
        held!.productID == revoked.productID &&
        (revoked.purchaseID == null ||
            held.purchaseID == null ||
            held.purchaseID == revoked.purchaseID));
    await _hasPurchase();
  }

  Future<void> deliverProduct(PurchaseDetails purchaseDetails, Map<String, Object> eventMap) async {
    // A restore is the store re-stating something the customer already paid for, and every cold
    // start replays it. It must apply the entitlement exactly as a purchase does — but silently:
    // thanking someone for "making this purchase" on each launch reads as a fresh charge, and
    // counting it as a purchase event made the purchase analytics meaningless.
    final bool isRestore = purchaseDetails.status == PurchaseStatus.restored;
    void thank(String message) {
      if (!isRestore) showSnackBar(message: message, isDismissible: true);
    }

    if (isRestore) {
      logger.i('PurchaseHelper: restored ${purchaseDetails.productID} (${purchaseDetails.purchaseID})');
    } else if (purchaseDetails.purchaseID != null) {
      // Use the prototype that stores consumables in the shared preferences
      await ConsumableStore.save(purchaseDetails.purchaseID!);
    } else {
      // A null purchaseID must NOT prevent the ad-free entitlement below from being applied — it
      // has been observed on some restore paths. Only record the consumable when we have an ID.
      logger.w(
          'PurchaseHelper: deliverProduct: purchaseID is null for ${purchaseDetails.productID}, skipping ConsumableStore.save');
    }

    switch (purchaseDetails.productID) {
      case SKU_DONATION_SMALL:
        {
          thank('Thanks so much for the coffee, you legend!');
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          isDonateSmallPurchased = true;
          await _hasPurchase();
          break;
        }
      case SKU_DONATION_MEDIUM:
        {
          thank('Coffee and cake is the best, just like you!');
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          isDonateMediumPurchased = true;
          await _hasPurchase();
          break;
        }
      case SKU_DONATION_LARGE:
        {
          thank('Thanks for buying lunch! I\'d love to hear from you.');
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          isDonateLargePurchased = true;
          await _hasPurchase();
          break;
        }
      case SKU_SUBSCRIBE_ONE_YEAR:
        {
          thank('Thanks! Enjoy the app now ad free for the next year.');
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          await _hasPurchase();
          break;
        }
      case SKU_SUBSCRIBE_PERMANENTLY:
        {
          thank('Thanks for making this purchase. Please enjoy the app ad free.');
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          await _hasPurchase();
          break;
        }
      default:
        {
          // A product this build doesn't know (a retired SKU, say). Nothing to deliver, and
          // nothing a user could act on — so no snackbar, least of all on every restore.
          logger.e('PurchaseHelper: unexpected product delivered: ${purchaseDetails.productID}');
          eventMap['unexpected'] = purchaseDetails.productID;
        }
    }

    notifyListeners();

    AnalyticsHelper().sendCustomAnalyticsEvent(
      eventName: isRestore ? 'purchase_restored' : 'purchase',
      eventParameters: eventMap,
    );
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    logger.e('_handleInvalidPurchase: Purchase status is ${purchaseDetails.status}');
    showSnackBar(message: '_handleInvalidPurchase: Purchase status is ${purchaseDetails.status}');
  }

  Future<void> consumeForDebuggingOnly({required String sku}) async {
    logger.d('$sku');
    PurchaseDetails? purchaseDetails = _purchases.firstWhere((product) {
      return product!.productID == sku;
    });
    if (purchaseDetails != null) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  //  Future<bool> _isSignatureValid(PurchaseDetails purchaseDetails) {
  //    return Future<bool>.value(Security.verifyPurchase(
  //        purchaseDetails.billingClientPurchase.originalJson,
  //        purchaseDetails.billingClientPurchase.signature));
  //  }
}

/// Example implementation of the
/// [`SKPaymentQueueDelegate`](https://developer.apple.com/documentation/storekit/skpaymentqueuedelegate?language=objc).
///
/// The payment queue delegate can be implemented to provide information
/// needed to complete transactions.
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
