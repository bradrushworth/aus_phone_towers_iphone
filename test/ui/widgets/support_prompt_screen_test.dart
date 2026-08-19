import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/ui/widgets/support_prompt_screen.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider<PurchaseHelper>.value(
        value: PurchaseHelper(),
        child: const MaterialApp(home: SupportPromptScreen()),
      ),
    );
  }

  // PurchaseHelper is a singleton — reset the flag this screen reads so state doesn't
  // leak between tests.
  tearDown(() {
    PurchaseHelper().isSubscribed = false;
  });

  group('SupportPromptScreen', () {
    testWidgets('shows the title, message and all three donation options', (tester) async {
      await pump(tester);
      expect(find.text(Strings.supportPromptTitle), findsOneWidget);
      expect(find.text(Strings.supportPromptMessage), findsOneWidget);
      expect(find.text(Strings.donateSmall), findsOneWidget);
      expect(find.text(Strings.donateMedium), findsOneWidget);
      expect(find.text(Strings.donateLarge), findsOneWidget);
      expect(find.text(Strings.supportPromptMaybeLater), findsOneWidget);
    });

    testWidgets('shows the ad-free options when the user is not yet ad-free', (tester) async {
      PurchaseHelper().isSubscribed = false;
      await pump(tester);
      expect(find.text(Strings.supportPromptAdfreeHeader), findsOneWidget);
      expect(find.text(Strings.remove_ads_year), findsOneWidget);
      expect(find.text(Strings.remove_ads_permanent), findsOneWidget);
    });

    testWidgets('hides the ad-free section once the user already has ads removed',
        (tester) async {
      PurchaseHelper().isSubscribed = true;
      await pump(tester);
      expect(find.text(Strings.supportPromptAdfreeHeader), findsNothing);
      expect(find.text(Strings.remove_ads_year), findsNothing);
      expect(find.text(Strings.remove_ads_permanent), findsNothing);
    });
  });
}
