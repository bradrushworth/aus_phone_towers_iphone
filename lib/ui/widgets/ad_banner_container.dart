import 'package:flutter/material.dart';

/// Bottom-of-screen container that reserves space for a banner ad only once
/// the ad's actual rendered size is known.
///
/// Inline adaptive banner ads (see [AdsHelper.showBannerAd]) always report
/// `height == 0` on the requested [BannerAd.size] — the real height is only
/// known once the ad has loaded, via `BannerAd.getPlatformAdSize()` (cached
/// as [AdsHelper.loadedAdSize]). Sizing this container from the requested
/// size instead of the loaded size collapses it to zero height, so a
/// successfully-loaded ad never becomes visible. See
/// `test/ui/widgets/ad_banner_container_test.dart` for the regression test.
///
/// [adSize] and [adChild] are plain Flutter types (not `AdSize`/`AdWidget`)
/// so this widget — and its sizing logic — can be exercised in a widget test
/// without depending on the `google_mobile_ads` platform channel.
class AdBannerContainer extends StatelessWidget {
  const AdBannerContainer({super.key, required this.adSize, required this.adChild});

  /// The actual rendered size of the loaded ad, or null if no ad has loaded.
  final Size? adSize;

  /// The platform ad view to display once [adSize] is known, or null.
  final Widget? adChild;

  @override
  Widget build(BuildContext context) {
    // The container wraps its content (label + ad) rather than using a fixed
    // height: adaptive banners vary from ~50px to 90+px with the viewport, so
    // any hardcoded height either overflows on tall ads ("BOTTOM OVERFLOWED"
    // stripe over the ad in debug builds) or reserves dead space above short
    // ones. Width is forced to fill so the backing strip always spans the
    // screen behind the centred ad, and the label stays flush against the
    // ad it discloses (AdMob placement policy — no gap between them).
    //
    // The strip and its label take their colours from the theme rather than a
    // hardcoded white/grey: in dark mode a white band across the bottom of a
    // dark map is the brightest thing on screen, which is exactly wrong at
    // night and was reported on iOS 1.14.4. The disclosure label keeps its
    // muted-but-legible contrast in both themes via onSurfaceVariant.
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('ad-banner-outer'),
      width: double.infinity,
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (adSize != null)
            Text(
              "Advertisement",
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          SizedBox(
            width: adSize == null ? 0 : adSize!.width,
            height: adSize == null ? 0 : adSize!.height,
            child: adSize == null || adChild == null ? Container() : adChild,
          ),
        ],
      ),
    );
  }
}
