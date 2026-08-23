import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/purchase_helper.dart';
import 'ad_banner_container.dart';

/// The bottom-anchored banner-ad region, gated on the user's ad-free
/// entitlement via a live [Consumer] of [PurchaseHelper].
///
/// Regression context ("I paid to remove ads but the ads still appear"):
/// this region used to be a plain `Visibility(visible:
/// !PurchaseHelper().isSubscribed, ...)` inside `MapBody.build`, read once per
/// build with no listener. At cold start the ad usually finishes loading
/// before `restorePurchases()` delivers the user's ad-free purchase, so the
/// ad rendered first — and when the entitlement then arrived and
/// `notifyListeners()` fired, nothing rebuilt this subtree. The already-drawn
/// ad strip (white backing, "Advertisement" label, last ad frame) stayed on
/// screen until some unrelated `setState`/provider rebuild happened to touch
/// the map UI. Wrapping the region in a `Consumer<PurchaseHelper>` makes it
/// react the moment the entitlement changes, in both directions (purchase or
/// restore hides it immediately; a yearly entitlement lapsing shows it again).
///
/// [adSize] and [adChild] are getters, not values: when the Consumer rebuilds
/// on a purchase notification it must re-read the *current* ad state
/// (`AdsHelper().hideBannerAd()` has typically just nulled both), not
/// whatever was captured when the enclosing widget last built. They are plain
/// Flutter types so this widget can be exercised in a widget test without the
/// `google_mobile_ads` platform channel — see
/// `test/ui/widgets/entitlement_gated_ad_banner_test.dart`.
class EntitlementGatedAdBanner extends StatelessWidget {
  const EntitlementGatedAdBanner({
    super.key,
    required this.adSize,
    required this.adChild,
  });

  /// Returns the actual rendered size of the currently loaded ad, or null if
  /// no ad is loaded (mirrors `AdsHelper().loadedAdSize`).
  final Size? Function() adSize;

  /// Returns the platform ad view for the currently loaded ad, or null
  /// (mirrors `AdWidget(ad: AdsHelper().bannerAd!)`).
  final Widget? Function() adChild;

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseHelper>(
      builder: (context, purchaseHelper, child) {
        // Visibility(visible: false) would keep the (disposed) ad subtree
        // alive; dropping it entirely releases the platform view too.
        if (purchaseHelper.isSubscribed) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: AdBannerContainer(adSize: adSize(), adChild: adChild()),
          ),
        );
      },
    );
  }
}
