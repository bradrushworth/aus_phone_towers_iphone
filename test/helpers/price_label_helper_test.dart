import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:phonetowers/helpers/price_label_helper.dart';

ProductDetails _product(String id, String price) {
  return ProductDetails(
    id: id,
    title: id,
    description: '',
    price: price,
    rawPrice: 0,
    currencyCode: 'AUD',
  );
}

void main() {
  group('PriceLabelHelper.findPrice', () {
    test('returns the price for a matching product', () {
      final price = PriceLabelHelper.findPrice([_product('sku_a', '\$5.99')], 'sku_a');
      expect(price, '\$5.99');
    });

    test('returns null when the product list is empty (store query not loaded yet)', () {
      expect(PriceLabelHelper.findPrice([], 'sku_a'), isNull);
    });

    test('returns null for an unknown sku not present in the product list', () {
      final price = PriceLabelHelper.findPrice([_product('sku_a', '\$5.99')], 'sku_b');
      expect(price, isNull);
    });

    test('ignores null entries in the product list', () {
      final price =
          PriceLabelHelper.findPrice([null, _product('sku_a', '\$5.99'), null], 'sku_a');
      expect(price, '\$5.99');
    });

    test('picks the store-localized price, not a hardcoded currency assumption', () {
      // e.g. a non-US/AU storefront could return "€5.49" or "£4.99" — findPrice must pass
      // the store's own formatted string through verbatim.
      final price = PriceLabelHelper.findPrice([_product('sku_a', '€5.49')], 'sku_a');
      expect(price, '€5.49');
    });
  });

  group('PriceLabelHelper.buildLabel', () {
    test('uses the live store price when the product has loaded', () {
      final label = PriceLabelHelper.buildLabel(
        products: [_product('sku_a', '\$5.99')],
        sku: 'sku_a',
        name: 'Morning Coffee',
        fallback: 'Morning Coffee (\$5.99 - fallback)',
      );
      expect(label, 'Morning Coffee (\$5.99)');
    });

    test('falls back to the provided text when pricing has not loaded yet', () {
      final label = PriceLabelHelper.buildLabel(
        products: [],
        sku: 'sku_a',
        name: 'Morning Coffee',
        fallback: 'Morning Coffee (\$5.99 - fallback)',
      );
      expect(label, 'Morning Coffee (\$5.99 - fallback)');
    });
  });
}
