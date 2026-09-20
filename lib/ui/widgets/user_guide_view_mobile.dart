import 'package:flutter/material.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Mobile (iOS/Android) body of `UserGuideScreen`: the bundled guide shown in a native WebView.
class UserGuideView extends StatefulWidget {
  const UserGuideView({super.key});

  /// True only for a navigation inside the bundled guide itself: the `file:` URL that
  /// [loadFlutterAsset] resolves to, or the `about:blank` the WebView starts on before that
  /// load completes. Null (unparsable) or any other scheme is treated as external.
  static bool isInternalNavigation(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'file' || uri.scheme == 'about';
  }

  @override
  State<UserGuideView> createState() => _UserGuideViewState();
}

class _UserGuideViewState extends State<UserGuideView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // The guide is fully self-contained (no scripts, no remote resources —
    // test/docs/user_guide_html_test.dart pins that), so JavaScript stays off, same as the
    // Android app; pinch zoom is on by default.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: _onNavigationRequest))
      ..loadFlutterAsset(kUserGuideAsset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Avoids a white flash in dark mode before the page paints.
    _controller.setBackgroundColor(Theme.of(context).colorScheme.surface);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (UserGuideView.isInternalNavigation(request.url)) {
      return NavigationDecision.navigate;
    }
    // The guide has no external links today; this keeps a future one from navigating the guide
    // page away from the guide, by handing it to the system instead.
    final Uri? uri = Uri.tryParse(request.url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
