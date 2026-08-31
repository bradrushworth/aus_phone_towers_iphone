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
  /// `buildLabel(products: products, sku: sku, name: 'Morning Coffee')` ->
  /// `"Morning Coffee ($5.99)"`.
  ///
  /// When the price isn't known — the store query is still in flight, failed, or the SKU is not
  /// in the storefront at all — the label is just [name], with no price. It deliberately does NOT
  /// substitute a hardcoded price: the fallbacks used to carry one (e.g. 'Morning Coffee
  /// ($5.99)'), so any drift between the app's product ids and App Store Connect, or any
  /// repricing, made the app quote a price the store would never charge. Showing no price is
  /// always truthful; showing a stale one is not.
  ///
  /// [fallback] remains available for a caller that genuinely has a better string than the bare
  /// name, but it must never be a hardcoded price.
  static String buildLabel({
    required List<ProductDetails?> products,
    required String sku,
    required String name,
    String? fallback,
  }) {
    final String? price = findPrice(products, sku);
    return price != null ? '$name ($price)' : (fallback ?? name);
  }
}
