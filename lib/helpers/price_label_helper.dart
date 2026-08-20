import 'package:in_app_purchase/in_app_purchase.dart';

/// Builds menu/screen labels from live App Store / Play Store pricing instead of a hardcoded
/// price, e.g. "Morning Coffee ($5.99)" using the store's own localized price string (which
/// already carries the correct currency symbol/formatting for the user's storefront) rather
/// than an assumed-USD/AUD literal baked into the app.
///
/// Kept pure (no StoreKit, no PurchaseHelper singleton) so it's unit-testable with an injected
/// product list — see PurchaseHelper.priceFor / priceLabel for the singleton-backed wrapper
/// used by the UI, and test/helpers/price_label_helper_test.dart.
class PriceLabelHelper {
  /// Finds the store's localized price string for [sku] within [products], or null if the
  /// product isn't present (store query still in flight, failed, or an unknown SKU).
  static String? findPrice(List<ProductDetails?> products, String sku) {
    for (final ProductDetails? product in products) {
      if (product?.id == sku) return product?.price;
    }
    return null;
  }

  /// Combines [name] with the live price for [sku] within [products] if known — e.g.
  /// `buildLabel(products: products, sku: sku, name: 'Morning Coffee', fallback: fallback)` ->
  /// `"Morning Coffee ($5.99)"`. Falls back to [fallback] (typically a hardcoded "Name ($X.XX)"
  /// string) when pricing hasn't loaded yet, so the menu never shows a broken/blank price.
  static String buildLabel({
    required List<ProductDetails?> products,
    required String sku,
    required String name,
    required String fallback,
  }) {
    final String? price = findPrice(products, sku);
    return price != null ? '$name ($price)' : fallback;
  }
}
