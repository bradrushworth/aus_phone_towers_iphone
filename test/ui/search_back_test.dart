import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/ui/widgets/search_back_scope.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(() => SearchHelper.calculatingSearchResults = false);

  test('canPop is false only while the search field is open', () {
    expect(SearchBackScope.canPop(searching: true), isFalse);
    expect(SearchBackScope.canPop(searching: false), isTrue);
  });

  testWidgets('Back closes the search field instead of popping the route', (tester) async {
    final helper = SearchHelper();
    helper.setSearchStatus(true);
    await tester.pumpWidget(
      ChangeNotifierProvider<SearchHelper>.value(
        value: helper,
        child: const MaterialApp(
          home: SearchBackScope(child: Scaffold(body: Text('map'))),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(SearchHelper.calculatingSearchResults, isFalse);
    expect(find.text('map'), findsOneWidget);
  });
}
