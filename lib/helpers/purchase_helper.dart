import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/billing/consumable_store.dart';
import 'package:phonetowers/billing/entitlement_cache.dart';
import 'package:phonetowers/billing/restore_outcome.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      await restorePurchases();
      await _getProducts();
      //await _hasPurchase();
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

  /// Restore all purchases from the store.
  ///
  /// Pass [userInitiated] true when called from a user-visible action (e.g. the
  /// "Restore purchases" menu item) to show a snackbar reporting the outcome —
  /// previously this method gave no feedback at all, leaving a tap on Restore
  /// looking like nothing happened. Note that restored transactions are
  /// delivered asynchronously via [_listenToPurchaseUpdated]/[purchaseStream]
  /// and may arrive slightly after this await completes; the outcome snackbar
  /// is based on best-effort current state and kept simple rather than
  /// awaiting the stream as well.
  Future<void> restorePurchases({bool userInitiated = false}) async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (error) {
      String message = 'Failed to restore purchases: $error';
      logger.e('PurchaseHelper: ' + message);
      AnalyticsHelper().log(message);
      showSnackBar(message: message);
      return;
    }

    if (userInitiated) {
      showSnackBar(message: restoreOutcomeMessage(isSubscribed: isSubscribed));
    }
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
  String priceLabel({required String sku, required String name, required String fallback}) =>
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
      _purchases = [];
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
      _purchases = [];
      _notFoundIds = productDetailResponse.notFoundIDs;
      _consumables = [];
      _purchasePending = false;
      _loading = false;
      return;
    }

    List<String> consumables = await ConsumableStore.load();
    _products = productDetailResponse.productDetails;
    _notFoundIds = productDetailResponse.notFoundIDs;
    _consumables = consumables;
    _purchasePending = false;
    _loading = false;
    String error = "In-App Billing is completed!";
    //showSnackBar(message: error);
    logger.i("PurchaseHelper: " + error);

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
          showSnackBar(
            message:
                "_hasPurchase: ${purchase.productID} has pendingCompletePurchase=${purchase.pendingCompletePurchase}",
          );
          //_inAppPurchase.completePurchase(purchase);
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

    showSnackBar(message: "_hasPurchase: ${listAllOwnedSkus.length}");
    for (PurchaseDetails? purchase in _purchases) {
      logger.d('purchased item is ${purchase!.productID}');
      showSnackBar(message: 'purchased item is ${purchase.productID}');
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

    // Only block if the exact SKU being purchased is already owned.
    // On Apple devices restorePurchases() populates _purchases with all past
    // purchases, so we must not block every purchase just because one exists.
    try {
      PurchaseDetails? purchaseDetails = _purchases.singleWhere((product) {
        return product!.productID == sku;
      });
      String error =
          'Matching product already bought... ${purchaseDetails!.productID} ${purchaseDetails.pendingCompletePurchase}';
      logger.i(error);
      showSnackBar(message: error);
      return;
    } catch (e) {
      logger.i('No previous matching purchase found for $sku, continuing...');
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
          if (productToBuy.id == SKU_SUBSCRIBE_PERMANENTLY ||
              productToBuy.id == SKU_SUBSCRIBE_ONE_YEAR) {
            // Ad-free purchases are non-consumable so they persist on the App Store and
            // are returned by restorePurchases() on future app launches. Consumables are
            // never restored on iOS, which would otherwise silently drop the ad-free
            // entitlement (e.g. yearly_adfree) after the app is closed and reopened.
            // This matches the Android app, which acknowledges but never consumes these SKUs.
            bought = await _inAppPurchase.buyNonConsumable(
              purchaseParam: purchaseParam,
            );
          } else {
            bought = await _inAppPurchase.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: false,
            );
          }
        showSnackBar(
          message: 'Selected to buy ${bought}: productDetails=${purchaseParam.productDetails.title}',
        );
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

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      Map<String, Object> eventMap = Map<String, Object>();
      if (purchaseDetails.status == PurchaseStatus.pending) {
        logger.w('Purchase status is ${purchaseDetails.status}');
        showSnackBar(message: 'Purchase status is ${purchaseDetails.status}');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          String error = 'Failed purchase of ${purchaseDetails.productID} ${purchaseDetails.purchaseID} ${purchaseDetails.error} ${purchaseDetails.transactionDate} ${purchaseDetails.verificationData} ${purchaseDetails.pendingCompletePurchase} ';
          showSnackBar(message: error);
          logger.e("PurchaseHelper: " + error);
          eventMap['failure'] = error;
          AnalyticsHelper().log(error);

          AnalyticsHelper().sendCustomAnalyticsEvent(
            eventName: 'purchase_error',
            eventParameters: eventMap,
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          logger.i('Purchase status is ${purchaseDetails.status}');
          showSnackBar(message: 'Purchase status is ${purchaseDetails.status}');
          bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await deliverProduct(purchaseDetails, eventMap);
          } else {
            _handleInvalidPurchase(purchaseDetails);
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
  }

  Future<void> deliverProduct(PurchaseDetails purchaseDetails, Map<String, Object> eventMap) async {
    // A null purchaseID must NOT prevent the ad-free entitlement below from
    // being applied — it has been observed on some restore paths. Only
    // record the consumable when we actually have an ID to record.
    if (purchaseDetails.purchaseID != null) {
      // Use the prototype that stores consumables in the shared preferences
      await ConsumableStore.save(purchaseDetails.purchaseID!);
    } else {
      logger.w(
          'PurchaseHelper: deliverProduct: purchaseID is null for ${purchaseDetails.productID}, skipping ConsumableStore.save');
    }

    switch (purchaseDetails.productID) {
      case SKU_DONATION_SMALL:
        {
          showSnackBar(message: 'Thanks so much for the coffee, you legend!', isDismissible: true);
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          isDonateSmallPurchased = true;
          await _hasPurchase();
          break;
        }
      case SKU_DONATION_MEDIUM:
        {
          showSnackBar(
            message: 'Coffee and cake is the best, just like you!',
            isDismissible: true,
          );
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          isDonateMediumPurchased = true;
          await _hasPurchase();
          break;
        }
      case SKU_DONATION_LARGE:
        {
          showSnackBar(
            message: 'Thanks for buying lunch! I\'d love to hear from you.',
            isDismissible: true,
          );
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          isDonateLargePurchased = true;
          await _hasPurchase();
          break;
        }
      case SKU_SUBSCRIBE_ONE_YEAR:
        {
          showSnackBar(
            message: 'Thanks! Enjoy the app now ad free for the next year.',
            isDismissible: true,
          );
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          await _hasPurchase();
          break;
        }
      case SKU_SUBSCRIBE_PERMANENTLY:
        {
          showSnackBar(
            message: 'Thanks for making this purchase. Please enjoy the app ad free.',
            isDismissible: true,
          );
          logger.i("PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          _purchases.add(purchaseDetails);
          await _hasPurchase();
          break;
        }
      default:
        {
          showSnackBar(
            message: 'This purchase condition shouldn\'t of happened! ${purchaseDetails.productID}',
            isDismissible: true,
          );
          logger.e("PurchaseHelper: This purchase condition shouldn\'t of happened! ${purchaseDetails.productID}");
        }
    }

    notifyListeners();

    AnalyticsHelper().sendCustomAnalyticsEvent(eventName: 'purchase', eventParameters: eventMap);
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
