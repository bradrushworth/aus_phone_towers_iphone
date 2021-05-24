import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

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
  InAppPurchaseConnection _iap = InAppPurchaseConnection.instance;
  List<ProductDetails> products = [];
  List<PurchaseDetails> purchases = [];
  StreamSubscription<List<PurchaseDetails>> subscription;

  static const String SKU_DONATION_SMALL = "donation_small";
  static const String SKU_DONATION_MEDIUM = "donation_medium";
  static const String SKU_DONATION_LARGE = "donation_large";
  static const String SKU_SUBSCRIBE_PERMANENTLY = "permanant_adfree";
  static const String SKU_SUBSCRIBE_ONE_YEAR = "yearly_adfree";

  bool isShowDonatePreviousMenuItem = false;
  bool isShowSubscribePreviousMenuItem = false;
  bool isSubscribedPermanently = false;
  String timeToExpireYearlySubscription = '';

  bool isDonateSmallPurchased = false;
  bool isDonateMediumPurchased = false;
  bool isDonateLargePurchased = false;

  final int EXPIRY_PERIOD = 365 * 24 * 60 * 60 * 1000;

  ShowSnackBar showSnackBar;

  bool isHasPurchasedProcessed = false;

  void initIAP(
      {void Function({String message, bool isDismissible})
          showSnackBar}) async {
    this.showSnackBar = showSnackBar;

    // Check availability of In App Purchases
    available = await _iap.isAvailable();

    // Report statistics to Firebase
    AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'setup_billing',
        eventParameters: <String, dynamic>{
          'message': available
              ? 'The Payment platform is ready and available'
              : 'The Payment platform is not ready and available',
        });

    if (available) {
      await _getProducts();
      await hasPurchase();

      // Listen to new purchases
      subscription = _iap.purchaseUpdatedStream.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {}, onError: (error) {});
    } else {
      // Oh no, there was a problem.
      String error = 'The Payment platform is not ready and available';
      logger.e('Error in PurchaseHelper: Error is $error');
      FirebaseCrashlytics.instance.log(error);
      showSnackBar(message: error);
    }
  }

  /// Get all products available for sale
  Future<void> _getProducts() async {
    Set<String> ids = Set.from([
      SKU_DONATION_SMALL,
      SKU_DONATION_MEDIUM,
      SKU_DONATION_LARGE,
      SKU_SUBSCRIBE_ONE_YEAR,
      SKU_SUBSCRIBE_PERMANENTLY
    ]);
    ProductDetailsResponse response = await _iap.queryProductDetails(ids);

    products = response.productDetails;
    products.forEach((productDetails) {
      logger.d('products are ${productDetails.id}');
    });
  }

  /// Gets past purchases
  Future<void> hasPurchase() async {
    QueryPurchaseDetailsResponse response = await _iap.queryPastPurchases();

    Map<String, dynamic> eventMap = Map<String, dynamic>();

    if (response.error != null) {
      String error = "In-App Billing Failed: " + response.error.message;
      showSnackBar(message: error);
      logger.e("PurchaseHelper", error);
      FirebaseCrashlytics.instance.log(error);
      eventMap['failure'] = error;
    } else {
      //Save all purchased items in temporary list
      purchases = response.pastPurchases;

      //1) Operation to show / hide donate previous menu
      PurchaseDetails purchaseDetailsForDonation = response.pastPurchases
          .firstWhere(
              (purchaseDetails) =>
                  purchaseDetails.productID == SKU_DONATION_SMALL ||
                  purchaseDetails.productID == SKU_DONATION_MEDIUM ||
                  purchaseDetails.productID == SKU_DONATION_LARGE,
              orElse: () => null);
      // Thank the user for donating in the past :-)
      eventMap['donation'] = purchaseDetailsForDonation != null ? true : false;
      isShowDonatePreviousMenuItem =
          purchaseDetailsForDonation != null ? true : false;

      //2)  Operation to perform when user has removed ad for one year
      PurchaseDetails purchaseDetailsForOneYearSubscription =
          response.pastPurchases.firstWhere(
              (purchaseDetails) =>
                  purchaseDetails.productID == SKU_SUBSCRIBE_ONE_YEAR,
              orElse: () => null);
      if (purchaseDetailsForOneYearSubscription != null) {
        int purchaseTime = int.tryParse(
                purchaseDetailsForOneYearSubscription.transactionDate) ??
            0;
        if (purchaseTime > 0 &&
            purchaseTime <
                DateTime.now().millisecondsSinceEpoch - EXPIRY_PERIOD) {
          // Remove ads for one year is now over
          logger.i("BillingHelper Consuming the " +
              SKU_SUBSCRIBE_ONE_YEAR +
              " purchase because it expired!");
          eventMap['expired_sku'] = SKU_SUBSCRIBE_ONE_YEAR;
          _iap.consumePurchase(purchaseDetailsForOneYearSubscription);
          isShowSubscribePreviousMenuItem = false;
        }
      }

      //3) This is just for analytics
      // This needs to be after the consume everything above
      PurchaseDetails purchaseDetailsForPermanentSubscription =
          response.pastPurchases.firstWhere(
              (purchaseDetails) =>
                  purchaseDetails.productID == SKU_SUBSCRIBE_PERMANENTLY,
              orElse: () => null);
      bool permanent =
          purchaseDetailsForPermanentSubscription != null ? true : false;
      bool yearly =
          purchaseDetailsForOneYearSubscription != null ? true : false;
      bool subscription = permanent || yearly;

      eventMap['permanent'] = permanent;
      eventMap['yearly'] = yearly;
      eventMap['subscription'] = subscription;
      List<String> listAllOwnedSkus = response.pastPurchases
          .map((purchaseDetails) => purchaseDetails.productID)
          .toList();
      eventMap['owned_sku'] = listAllOwnedSkus.toString();

      // Stop users from subscribing more than once
      isShowSubscribePreviousMenuItem = subscription;
      isSubscribedPermanently = permanent;
      if (yearly) {
        int expiry = int.tryParse(
                purchaseDetailsForOneYearSubscription.transactionDate) ??
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
      for (PurchaseDetails purchase in response.pastPurchases) {
        logger.d('purchased item is ${purchase.productID}');
        if (Platform.isIOS) {
          InAppPurchaseConnection.instance.completePurchase(purchase);
        }
      }
    }

    AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'has_purchase', eventParameters: eventMap);
  }


  Future<void> initiatePurchase({@required String sku}) async {
    //If product is already purchased, First consume it and then buy again
    PurchaseDetails purchaseDetails = purchases.firstWhere((product) {
      return product.productID == sku;
    }, orElse: () => null);
    if (purchaseDetails != null) {
      await _iap.consumePurchase(purchaseDetails);
    }

    ProductDetails productToBuy = products.firstWhere((product) {
      return product.id == sku;
    }, orElse: () => null);
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productToBuy);
    if (productToBuy != null) {
      _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: false);
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      Map<String, dynamic> eventMap = Map<String, dynamic>();
      if (purchaseDetails.status == PurchaseStatus.pending) {
        logger.w('Purchase status is ${purchaseDetails.status}');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          logger.e('Purchase status is ${purchaseDetails.status}');
          String error = 'Failed purchase: ${purchaseDetails.status}';
          showSnackBar(message: error);
          logger.w("PurchaseHelper", error);
          eventMap['failure'] = error;
          FirebaseCrashlytics.instance.log(error);

          AnalyticsHelper().sendCustomAnalyticsEvent(
              eventName: 'purchase', eventParameters: eventMap);
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
          InAppPurchaseConnection.instance.completePurchase(purchaseDetails);
        }
      }
    });
  }

  void deliverProduct(
      PurchaseDetails purchaseDetails, Map<String, dynamic> eventMap) {
    switch (purchaseDetails.productID) {
      case SKU_DONATION_SMALL:
        {
          showSnackBar(
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
          showSnackBar(
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
          showSnackBar(
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
          showSnackBar(
              message:
                  'Thanks for making this purchase. Please enjoy the app ad free.',
              isDismissible: true);
          logger.i(
              "PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          hasPurchase();
          break;
        }
      case SKU_SUBSCRIBE_PERMANENTLY:
        {
          showSnackBar(
              message:
                  'Thanks for making this purchase. Please enjoy the app ad free.',
              isDismissible: true);
          logger.i(
              "PurchaseHelper: Product purchased just now is ${purchaseDetails.productID}");
          eventMap['purchase'] = purchaseDetails.productID;
          hasPurchase();
          break;
        }
    }

    notifyListeners();

    AnalyticsHelper().sendCustomAnalyticsEvent(
        eventName: 'purchase', eventParameters: eventMap);
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {}

  Future<void> consumeforDebuggingOnly({@required String sku}) async {
    logger.d('$sku');
    PurchaseDetails purchaseDetails = purchases.firstWhere((product) {
      return product.productID == sku;
    }, orElse: () => null);
    if (purchaseDetails != null) {
      await _iap.consumePurchase(purchaseDetails);
    }
  }

//  Future<bool> _isSignatureValid(PurchaseDetails purchaseDetails) {
//    return Future<bool>.value(Security.verifyPurchase(
//        purchaseDetails.billingClientPurchase.originalJson,
//        purchaseDetails.billingClientPurchase.signature));
//  }
}
