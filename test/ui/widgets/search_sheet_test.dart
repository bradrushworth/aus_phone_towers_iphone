import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/ui/widgets/search_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  SearchResult result(String id, String name) => SearchResult(
      siteId: id,
      name: name,
      state: 'ACT',
      postcode: '2602',
      geohash: 'r3dp4',
      latitude: -35.25,
      longitude: 149.13);

  Future<void> open(WidgetTester tester, List<SearchResult> results) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                SearchSheet.show(context, 'Northbourne', results, (g, e) {}, null),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('search sheet renders results without throwing', (tester) async {
    await open(tester, [result('1', 'Telstra Site 490 Northbourne Ave'), result('2', 'Optus Site')]);
    expect(find.textContaining('2 sites match'), findsOneWidget);
    expect(find.text('Telstra Site 490 Northbourne Ave'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search sheet renders the empty state without throwing', (tester) async {
    await open(tester, []);
    expect(find.textContaining('No sites match'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Regression: the map failing to initialise (e.g. the web build's Maps JS API rejecting the
  // key) must not take search down with it. Previously the submit handler read a `late`
  // mapController, so a missing map threw LateInitializationError inside onSubmitted.
  testWidgets('tapping a result with no map controller does not throw', (tester) async {
    String? requestedGeohash;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => SearchSheet.show(
                context,
                'Northbourne',
                [result('1', 'Telstra Site 490 Northbourne Ave')],
                (g, e) => requestedGeohash = g,
                null), // map never initialised
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Telstra Site 490 Northbourne Ave'));
    await tester.pumpAndSettle();
    // Let the deferred "open the site sheet once the tile lands" timer elapse.
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
    expect(requestedGeohash, 'r3dp4'); // the tile still downloads without a camera
  });
}
