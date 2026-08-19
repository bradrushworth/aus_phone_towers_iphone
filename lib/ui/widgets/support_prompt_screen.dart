import 'package:flutter/material.dart';
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
                  child: Text(Strings.donateSmall),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _logAndPurchase(
                      context, 'donate_medium', PurchaseHelper.SKU_DONATION_MEDIUM),
                  child: Text(Strings.donateMedium),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _logAndPurchase(
                      context, 'donate_large', PurchaseHelper.SKU_DONATION_LARGE),
                  child: Text(Strings.donateLarge),
                ),
                if (!purchaseHelper.isSubscribed) ...[
                  const SizedBox(height: 24),
                  Text(Strings.supportPromptAdfreeHeader,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _logAndPurchase(context, 'subscribe_yearly',
                        PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR),
                    child: Text(Strings.remove_ads_year),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _logAndPurchase(context, 'subscribe_permanent',
                        PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY),
                    child: Text(Strings.remove_ads_permanent),
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
}
