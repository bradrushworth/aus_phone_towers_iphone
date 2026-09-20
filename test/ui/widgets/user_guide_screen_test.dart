import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/ui/widgets/user_guide_screen.dart';
import 'package:phonetowers/ui/widgets/user_guide_view_mobile.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// `flutter test` has no real native WebView, so these tests install a fake `WebViewPlatform`
/// and pin the *values* [UserGuideScreen]/[UserGuideView] hand it, rather than any pixels:
/// JavaScript stays disabled, the loaded asset key matches [kUserGuideAsset] exactly (a typo
/// here would silently ship a blank page), and the guide is reachable and dismissible like any
/// other pushed screen. The fake platform deliberately leaves every call other than the ones
/// `UserGuideView` is known to make unimplemented (the base class throws), so if it starts
/// calling something new, this test fails loudly instead of a real device silently no-opping.
///
/// [UserGuideView.isInternalNavigation] is exercised directly, since it is a pure function with
/// no platform dependency — see user_guide_view_mobile.dart.
void main() {
  late _FakeWebViewPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeWebViewPlatform();
    WebViewPlatform.instance = fakePlatform;
  });

  group('UserGuideScreen', () {
    testWidgets('renders the bundled guide with JavaScript off', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserGuideScreen()));
      await tester.pumpAndSettle();

      expect(find.text('User Guide'), findsOneWidget);
      expect(find.byKey(const Key('fake-webview')), findsOneWidget);

      final _FakeWebViewController? controller = fakePlatform.lastController;
      expect(controller, isNotNull);
      expect(controller!.javaScriptMode, JavaScriptMode.disabled);
      expect(controller.loadedAssetKey, 'docs/user-guide.html');
      expect(controller.loadedAssetKey, kUserGuideAsset);
      expect(controller.backgroundColor, isNotNull);
    });

    testWidgets('open() pushes the guide as a page and Back returns', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => UserGuideScreen.open(context),
            child: const Text('Open guide'),
          ),
        ),
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.byType(UserGuideScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(UserGuideScreen), findsNothing);
    });
  });

  group('UserGuideView.isInternalNavigation', () {
    test('only the bundled guide navigates inside the WebView', () {
      expect(
          UserGuideView.isInternalNavigation(
              'file:///x/flutter_assets/docs/user-guide.html#leaderboard'),
          isTrue);
      expect(UserGuideView.isInternalNavigation('about:blank'), isTrue);

      expect(UserGuideView.isInternalNavigation('https://example.com/'), isFalse);
      expect(UserGuideView.isInternalNavigation('mailto:a@b.c'), isFalse);
      expect(UserGuideView.isInternalNavigation(''), isFalse);
    });
  });
}

/// Fake `WebViewPlatform`: routes the three `webview_flutter` factory calls to the fakes below
/// and remembers the controller so tests can inspect what `UserGuideView` told it to do.
class _FakeWebViewPlatform extends WebViewPlatform {
  _FakeWebViewController? lastController;

  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final _FakeWebViewController controller = _FakeWebViewController(params);
    lastController = controller;
    return controller;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) {
    return _FakeWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
      PlatformNavigationDelegateCreationParams params) {
    return _FakeNavigationDelegate(params);
  }
}

/// Records the handful of controller calls `UserGuideView` makes. Everything else falls through
/// to the base class's `UnimplementedError` — see the header comment on why that is wanted.
class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  JavaScriptMode? javaScriptMode;
  String? loadedAssetKey;
  Color? backgroundColor;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    this.javaScriptMode = javaScriptMode;
  }

  @override
  Future<void> loadFlutterAsset(String key) async {
    loadedAssetKey = key;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {
    backgroundColor = color;
  }

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}
}

/// Records the navigation-request callback `UserGuideView` installs, so setting it doesn't hit
/// the base class's `UnimplementedError` during a pump.
class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {
    this.onNavigationRequest = onNavigationRequest;
  }
}

/// Stands in for the native WebView surface with a plain, keyed box so tests can find it.
class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(key: Key('fake-webview'));
  }
}
