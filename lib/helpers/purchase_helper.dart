import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/billing/consumable_store.dart';

import 'analytics_helper.dart';

typedef void ShowSnackBar({String message, bool isDismissible});

class PurchaseHelper with ChangeNotifier {
  static final PurchaseHelper _singleton = new PurchaseHelper._internal();

  factory PurchaseHelper() {
    return _singleton;
  }

  PurchaseHelper._internal();

  Logger logger = Logger();

  /// Is the API available on the device
  bool available = false;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<String> _notFoundIds = [];
  List<ProductDetails?> _products = [];
  List<PurchaseDetails?> _purchases = [];
  List<String> _consumables = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;
  String? _queryProductError;

  static const String SKU_DONATION_SMALL = "donation_small";
  static const String SKU_DONATION_MEDIUM = "donation_medium";
  static const String SKU_DONATION_LARGE = "donation_large";
  static const String SKU_SUBSCRIBE_PERMANENTLY = "permanant_adfree";
  static const String SKU_SUBSCRIBE_ONE_YEAR = "yearly_adfree";

  final Set<String> _kProductIds = Set.from([
    SKU_DONATION_SMALL,
    SKU_DONATION_MEDIUM,
    SKU_DONATION_LARGE,
    SKU_SUBSCRIBE_ONE_YEAR,
    SKU_SUBSCRIBE_PERMANENTLY
  ]);

  bool isShowDonatePreviousMenuItem = false;
  bool isShowSubscribePreviousMenuItem = false;
  bool isSubscribedPermanently = false;
  String timeToExpireYearlySubscription = '';

  bool isDonateSmallPurchased = false;
  bool isDonateMediumPurchased = false;
  bool isDonateLargePurchased = false;

  final int EXPIRY_PERIOD = 365 * 24 * 60 * 60 * 1000;

  ShowSnackBar? showSnackBar;

  bool isHasPurchasedProcessed = false;

  void initStoreInfo(
      {void Function({String message, bool isDismissible})?
          showSnackBar}) async {
    this.showSnackBar = showSnackBar;

    // Check availability of In App Purchases
    final available = await _inAppPurchase.isAvailable();

    // Report statistics to Firebase
    AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'setup_billing',
        eventParameters: <String, Object>{
          'message': available
              ? 'The Payment platform is ready and available'
              : 'The Payment platform is not ready and available',
        });

    if (available) {
      // Listen to new purchases
      final Stream<List<PurchaseDetails>> purchaseUpdated =
          _inAppPurchase.purchaseStream;
      _subscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription!.cancel();
      }, onError: (error) {
        // handle error here.
      });

      await _getProducts();
      await _hasPurchase();
    } else {
      // Oh no, there was a problem.
      String error = 'The Payment platform is not ready and available';
      logger.e('Error in PurchaseHelper: Error is $error');
      AnalyticsHelper().log(error);
      showSnackBar!(message: error);

      _products = [];
      _purchases = [];
      _notFoundIds = [];
      _consumables = [];
      _purchasePending = false;
      _loading = false;
      return;
    }
  }

  /// Get all products available for sale
  Future<void> _getProducts() async {
    if (Platform.isIOS) {
      var iosPlatformAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (productDetailResponse.error != null) {
      String error =
          "In-App Billing Failed: " + productDetailResponse.error!.message;
      showSnackBar!(message: error);
      logger.e("PurchaseHelper", error);
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

    if (productDetailResponse.productDetails.isEmpty) {
      String error = "In-App Billing is empty!";
      showSnackBar!(message: error);
      logger.e("PurchaseHelper", error);
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
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      var iosPlatformAddition = _inAppPurchase
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
    Map<String, PurchaseDetails> purchases =
        Map.fromEntries(_purchases.map((PurchaseDetails? purchase) {
      if (purchase!.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
      return MapEntry<String, PurchaseDetails>(purchase.productID, purchase);
    }));
    _purchases = purchases.values.toList();

    Map<String, Object> eventMap = Map<String, Object>();

    //1) Operation to show / hide donate previous menu
    PurchaseDetails? purchaseDetailsForDonation = _purchases.firstWhere(
        (purchaseDetails) =>
            purchaseDetails!.productID == SKU_DONATION_SMALL ||
            purchaseDetails.productID == SKU_DONATION_MEDIUM ||
            purchaseDetails.productID == SKU_DONATION_LARGE,
        orElse: () => null);
    // Thank the user for donating in the past :-)
    eventMap['donation'] = purchaseDetailsForDonation != null ? true : false;
    isShowDonatePreviousMenuItem =
        purchaseDetailsForDonation != null ? true : false;

    //2)  Operation to perform when user has removed ad for one year
    PurchaseDetails? purchaseDetailsForOneYearSubscription =
        _purchases.firstWhere(
            (purchaseDetails) =>
                purchaseDetails!.productID == SKU_SUBSCRIBE_ONE_YEAR,
            orElse: () => null);
    if (purchaseDetailsForOneYearSubscription != null) {
      int purchaseTime =
          int.tryParse(purchaseDetailsForOneYearSubscription.transactionDate!) ??
              0;
      if (purchaseTime > 0 &&
          purchaseTime <
              DateTime.now().millisecondsSinceEpoch - EXPIRY_PERIOD) {
        // Remove ads for one year is now over
        logger.i("BillingHelper Consuming the " +
            SKU_SUBSCRIBE_ONE_YEAR +
            " purchase because it expired!");
        eventMap['expired_sku'] = SKU_SUBSCRIBE_ONE_YEAR;
        _inAppPurchase.completePurchase(purchaseDetailsForOneYearSubscription);
        isShowSubscribePreviousMenuItem = false;
      }
    }

    //3) This is just for analytics
    // This needs to be after the consume everything above
    PurchaseDetails? purchaseDetailsForPermanentSubscription =
        _purchases.firstWhere(
            (purchaseDetails) =>
                purchaseDetails!.productID == SKU_SUBSCRIBE_PERMANENTLY,
            orElse: () => null);
    bool permanent =
        purchaseDetailsForPermanentSubscription != null ? true : false;
    bool yearly = purchaseDetailsForOneYearSubscription != null ? true : false;
    bool subscription = permanent || yearly;

    eventMap['permanent'] = permanent;
    eventMap['yearly'] = yearly;
    eventMap['subscription'] = subscription;
    List<String> listAllOwnedSkus =
        _purchases.map((purchaseDetails) => purchaseDetails!.productID).toList();
    eventMap['owned_sku'] = listAllOwnedSkus.toString();

    // Stop users from subscribing more than once
    isShowSubscribePreviousMenuItem = subscription;
    isSubscribedPermanently = permanent;
    if (yearly) {
      int expiry =
          int.tryParse(purchaseDetailsForOneYearSubscription.transactionDate!) ??
              0;
      expiry += EXPIRY_PERIOD;
      DateTime date = new DateTime.fromMillisecondsSinceEpoch(expiry);
      await initializeDateFormatting("en-AU", null);
      var formatter = DateFormat.yMMMd('en-AU');
      String expiryDate = formatter.format(date);
      timeToExpireYearlySubscription = 'Expires $expiryDate';
      eventMap['yearly_expiry'] = expiry;
    }

    // Remove or display the ads
    isHasPurchasedProcessed = true;
    notifyListeners();

    //This is required only for iOS
    for (PurchaseDetails? purchase in _purchases) {
      logger.d('purchased item is ${purchase!.productID}');
      if (Platform.isIOS) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }

    AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'has_purchase', eventParameters: eventMap);
  }

  Future<void> initiatePurchase({required String sku}) async {
    //If product is already purchased, First consume it and then buy again
    PurchaseDetails? purchaseDetails = _purchases.firstWhere((product) {
      return product!.productID == sku;
    }, orElse: () => null);
    if (purchaseDetails != null) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }

    ProductDetails? productToBuy = _products.firstWhere((product) {
      return product!.id == sku;
    }, orElse: () => null);
    if (productToBuy != null) {
      final PurchaseParam purchaseParam =
      PurchaseParam(productDetails: productToBuy);
      _inAppPurchase.buyConsumable(
          purchaseParam: purchaseParam, autoConsume: false);
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      Map<String, Object> eventMap = Map<String, Object>();
      if (purchaseDetails.status == PurchaseStatus.pending) {
        logger.w('Purchase status is ${purchaseDetails.status}');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          logger.e('Purchase status is ${purchaseDetails.status}');
          String error = 'Failed purchase: ${purchaseDetails.status}';
          showSnackBar!(message: error);
          logger.w("PurchaseHelper", error);
          eventMap['failure'] = error;
          AnalyticsHelper().log(error);

          AnalyticsHelper().sendCustomAnalyticsEvent(
              eventName: 'purchase_error', eventParameters: eventMap);
        } else if (purchaseDetails.status == PurchaseStatus.purchased) {
          bool valid = true;
          //await _verifyPurchase(purchaseDetails);
          if (valid) {
            deliverProduct(purchaseDetails, eventMap);
          } else {
            _handleInvalidPurchase(purchaseDetails);
          }
        }
        if (Platform.isIOS) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    });
  }

  void deliverProduct(
      PurchaseDetails purchaseDetails, Map<String, Object> eventMap) {
    switch (purchaseDetails.productID) {
      case SKU_DONATION_SMALL:
        {
          showSnackBar!(
              message: 'Thanks so much for the coffee, you legend!',
              isDismissible: true);
          logger.i(
              "PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          isDonateSmallPurchased = true;
          break;
        }
      case SKU_DONATION_MEDIUM:
        {
          showSnackBar!(
              message: 'Coffee and cake is the best, just like you!',
              isDismissible: true);
          logger.i(
              "PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          isDonateMediumPurchased = true;
          break;
        }
      case SKU_DONATION_LARGE:
        {
          showSnackBar!(
              message: 'Thanks for buying lunch! I\'d love to hear from you.',
              isDismissible: true);
          logger.i(
              "PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          isDonateLargePurchased = true;
          break;
        }
      case SKU_SUBSCRIBE_ONE_YEAR:
        {
          showSnackBar!(
              message:
                  'Thanks for making this purchase. Please enjoy the app ad free.',
              isDismissible: true);
          logger.i(
              "PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          //hasPurchase();
          break;
        }
      case SKU_SUBSCRIBE_PERMANENTLY:
        {
          showSnackBar!(
              message:
                  'Thanks for making this purchase. Please enjoy the app ad free.',
              isDismissible: true);
          logger.i(
              "PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          //hasPurchase();
          break;
        }
    }

    notifyListeners();

    AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'purchase', eventParameters: eventMap);
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {}

  Future<void> consumeforDebuggingOnly({required String sku}) async {
    logger.d('$sku');
    PurchaseDetails? purchaseDetails = _purchases.firstWhere((product) {
      return product!.productID == sku;
    }, orElse: () => null);
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
/// The payment queue delegate can be implementated to provide information
/// needed to complete transactions.
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
