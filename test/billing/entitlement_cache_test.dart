import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:phonetowers/billing/entitlement_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntitlementCache', () {
    test('nothing cached -> not subscribed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final result = EntitlementCache.read(prefs, nowMillis: 1000);

      expect(result.isSubscribed, isFalse);
      expect(result.isSubscribedPermanently, isFalse);
    });

    test('savePermanent -> read returns permanent subscribed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await EntitlementCache.savePermanent(prefs);
      final result = EntitlementCache.read(prefs, nowMillis: 1000);

      expect(result.isSubscribed, isTrue);
      expect(result.isSubscribedPermanently, isTrue);
    });

    test('saveYearly unexpired -> read returns subscribed, not permanent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const int expiry = 5000;
      await EntitlementCache.saveYearly(prefs, yearlyExpiryEpoch: expiry);
      final result = EntitlementCache.read(prefs, nowMillis: expiry - 1);

      expect(result.isSubscribed, isTrue);
      expect(result.isSubscribedPermanently, isFalse);
    });

    test('saveYearly expired -> read returns not subscribed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const int expiry = 5000;
      await EntitlementCache.saveYearly(prefs, yearlyExpiryEpoch: expiry);
      final result = EntitlementCache.read(prefs, nowMillis: expiry);

      expect(result.isSubscribed, isFalse);
      expect(result.isSubscribedPermanently, isFalse);
    });

    test('clear -> read returns not subscribed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await EntitlementCache.savePermanent(prefs);
      await EntitlementCache.clear(prefs);
      final result = EntitlementCache.read(prefs, nowMillis: 1000);

      expect(result.isSubscribed, isFalse);
      expect(result.isSubscribedPermanently, isFalse);
    });
  });
}
