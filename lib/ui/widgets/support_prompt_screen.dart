import 'package:flutter/material.dart';
import 'package:phonetowers/utils/utils.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';

import '../../helpers/analytics_helper.dart';
import '../../helpers/purchase_helper.dart';
import '../../utils/strings.dart';

/// "Support the App" — a full-screen ask for a donation or an ad-free purchase, ported from
/// the Java app's `SupportPromptActivity`. Reachable both from the last item of the Donate
/// menu (`OptionMenuItem.donate` -> Donate submenu -> "Support the App") and automatically
/// once a week (see `SupportPromptHelper` / `MapBodyState._maybeShowSupportPrompt`).
///
/// Note: the Java screen also offers a "Watch a short ad instead" button (a rewarded ad).
/// That isn't ported here — this app has no rewarded/interstitial ad unit configured (only
/// banner ads), and a real AdMob rewarded ad unit ID would need to be created first.
class SupportPromptScreen extends StatelessWidget {
  const SupportPromptScreen({super.key});

  void _logAndPurchase(BuildContext context, String action, String sku) {
    AnalyticsHelper().sendCustomAnalyticsEvent(
      eventName: 'support_prompt_$action',
      eventParameters: <String, Object>{},
    );
    PurchaseHelper().initiatePurchase(sku: sku);
    Navigator.of(context).pop();
  }

  void _dismiss(BuildContext context) {
    AnalyticsHelper().sendCustomAnalyticsEvent(
      eventName: 'support_prompt_dismiss',
      eventParameters: <String, Object>{},
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseHelper>(
      builder: (context, purchaseHelper, child) => Scaffold(
        appBar: AppBar(title: Text(Strings.supportPromptTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(Strings.supportPromptMessage, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 24),
                Text(Strings.supportPromptDonateHeader,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _logAndPurchase(
                      context, 'donate_small', PurchaseHelper.SKU_DONATION_SMALL),
                  child: Text(purchaseHelper.priceLabel(
                      sku: PurchaseHelper.SKU_DONATION_SMALL,
                      name: Strings.donateSmallName,
                      fallback: Strings.donateSmall)),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _logAndPurchase(
                      context, 'donate_medium', PurchaseHelper.SKU_DONATION_MEDIUM),
                  child: Text(purchaseHelper.priceLabel(
                      sku: PurchaseHelper.SKU_DONATION_MEDIUM,
                      name: Strings.donateMediumName,
                      fallback: Strings.donateMedium)),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _logAndPurchase(
                      context, 'donate_large', PurchaseHelper.SKU_DONATION_LARGE),
                  child: Text(purchaseHelper.priceLabel(
                      sku: PurchaseHelper.SKU_DONATION_LARGE,
                      name: Strings.donateLargeName,
                      fallback: Strings.donateLarge)),
                ),
                if (!purchaseHelper.isSubscribed) ...[
                  const SizedBox(height: 24),
                  Text(Strings.supportPromptAdfreeHeader,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _logAndPurchase(context, 'subscribe_yearly',
                        PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR),
                    child: Text(purchaseHelper.priceLabel(
                        sku: PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR,
                        name: Strings.remove_ads_year_name,
                        fallback: Strings.remove_ads_year)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _logAndPurchase(context, 'subscribe_permanent',
                        PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY),
                    child: Text(purchaseHelper.priceLabel(
                        sku: PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY,
                        name: Strings.remove_ads_permanent_name,
                        fallback: Strings.remove_ads_permanent)),
                  ),
                ],
                // Rating costs the user nothing and helps the app more than a small donation
                // does, so it belongs on the page where someone has already decided they want to
                // help. It also existed only in the settings sheet, which is not where anyone
                // looks when they are feeling generous. Not offered on web, where there is no
                // store to rate in.
                if (!kIsWeb) ...[
                  const SizedBox(height: 24),
                  Text(Strings.supportPromptRateHeader,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _rateTheApp,
                    child: Text(Strings.supportPromptRateAction),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  Strings.supportPromptThanks,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _dismiss(context),
                  child: Text(Strings.supportPromptMaybeLater),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ask the store for its in-app review sheet, falling back to the store listing.
  ///
  /// requestReview() is silently rate-limited by both stores and may show nothing at all, so a
  /// user who deliberately tapped "Rate the app" could otherwise get no feedback whatsoever. The
  /// listing is opened as well so the action always visibly does something.
  Future<void> _rateTheApp() async {
    final InAppReview inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    }
    Utils.launchURL(Platform.isAndroid
        ? 'https://play.google.com/store/apps/details?id=au.com.bitbot.phonetowers.flutter'
        : 'https://apps.apple.com/us/app/aus-phone-towers-3g-4g-5g/id1488594332');
  }
}
