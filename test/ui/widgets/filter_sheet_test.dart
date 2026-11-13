import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/ui/widgets/filter_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The 3G UMTS chip was removed (2026-11-08, matching Android 7.11.0): with frequency refarming on
// no transmitter is ever UMTS, so the chip did nothing. Nothing can unhide UMTS any more, so it
// must never be hidden, or turning refarming off would show no 3G licences at all.
void main() {
  void resetStaticState() {
    SiteHelper.globalListMapOverlay = [];
    SiteHelper.hideTelco = <Telco>{};
    SiteHelper.hideNetworkType = <NetworkType>{};
    SiteHelper.hideFrequency = <List<int>>{};
    SiteHelper.hideDensity = <CityDensity>{};
  }

  setUp(resetStaticState);
  tearDown(resetStaticState);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => FilterSheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('FilterSheet generation chips', () {
    testWidgets('offers 2G, 4G and 5G but no 3G chip', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openSheet(tester);

      expect(find.text('Generation'.toUpperCase()), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '2G GSM'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '4G LTE'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '5G NR'), findsOneWidget);
      expect(find.text('3G UMTS'), findsNothing);
    });

    testWidgets('a 3G choice saved by an older version is ignored', (tester) async {
      SharedPreferences.setMockInitialValues({'is3GVisible': false});
      await openSheet(tester);

      expect(find.text('3G UMTS'), findsNothing);
      expect(FilterSheet.activeFilterCount(), 0);
      expect(SiteHelper.hideNetworkType.contains(NetworkType.UMTS), isFalse);
    });

    testWidgets('turning the other generations off never hides UMTS', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openSheet(tester);

      for (final label in ['2G GSM', '4G LTE', '5G NR']) {
        await tester.tap(find.widgetWithText(FilterChip, label));
        await tester.pumpAndSettle();
      }

      expect(SiteHelper.hideNetworkType,
          {NetworkType.GSM, NetworkType.LTE, NetworkType.NR});
      expect(FilterSheet.activeFilterCount(), 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('is3GVisible'), isFalse);

      // Put the static filters back for the rest of the suite.
      for (final label in ['2G GSM', '4G LTE', '5G NR']) {
        await tester.tap(find.widgetWithText(FilterChip, label));
        await tester.pumpAndSettle();
      }
      expect(SiteHelper.hideNetworkType, isEmpty);
    });
  });

  group('UMTS visibility', () {
    test('with refarming off, a literal 3G licence is shown under the default filters', () {
      final saved = DeviceDetails.refarmEnabled;
      try {
        DeviceDetails.refarmEnabled = false;
        final site = Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN)
          ..siteId = '1234567'
          ..name = 'Optus Test Site';
        final device = DeviceDetails(
            networkType: DeviceDetails.getNetworkTypeForLicence(
                '20M0W7W', 2140000000, 20000000, Telco.Optus, 0))
          ..emission = '20M0W7W'
          ..frequency = 2140000000
          ..bandwidth = 20000000
          ..active = 'active'
          ..sddId = '99999999';
        device.setSite(site);
        site.getDeviceDetailsMobile().add(device);

        expect(device.getNetworkType(), NetworkType.UMTS);
        expect(SiteHelper.hideNetworkType.contains(NetworkType.UMTS), isFalse);
        expect(site.shouldBeVisible(), isTrue);
      } finally {
        DeviceDetails.refarmEnabled = saved;
      }
    });
  });
}
