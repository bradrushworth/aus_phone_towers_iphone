import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:web/web.dart' as web;

/// Web build's guide body: an `<iframe>` pointed at the bundled asset URL. webview_flutter has
/// no endorsed web implementation, so this is the web-only counterpart to the mobile WebView in
/// user_guide_view_mobile.dart.
class UserGuideView extends StatelessWidget {
  const UserGuideView({super.key});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final web.HTMLIFrameElement frame = element as web.HTMLIFrameElement;
        // sandbox BEFORE src so the policy applies to the load. Without allow-scripts the frame
        // runs no scripts, forms, popups or top-level navigation: the web equivalent of the mobile
        // WebView's JavaScriptMode.disabled. In-page #anchor links still work.
        //
        // allow-same-origin is deliberate and, with scripts off, grants the page nothing it can
        // use. It only stops the frame getting an opaque "null" origin, which matters twice: the
        // Flutter service worker will not serve a cached asset to an opaque-origin frame (so the
        // guide would need the network even in an installed PWA), and embedded browsers and
        // privacy tools that refuse opaque-origin sub-frames show a blank page instead — seen with
        // net::ERR_BLOCKED_BY_CLIENT under an empty sandbox while testing this.
        frame.setAttribute('sandbox', 'allow-same-origin');
        frame.title = Strings.userGuide;
        frame.style.border = 'none';
        frame.style.width = '100%';
        frame.style.height = '100%';
        frame.src = ui_web.assetManager.getAssetUrl(kUserGuideAsset);
      },
    );
  }
}
