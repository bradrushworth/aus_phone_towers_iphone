import 'package:flutter/material.dart';
import 'package:phonetowers/utils/strings.dart';

import 'user_guide_view_mobile.dart'
    if (dart.library.js_interop) 'user_guide_view_web.dart';

/// The in-app User Guide — a port of the Android app's `UserGuideActivity`.
///
/// The guide content is `docs/user-guide.html`, bundled as the Flutter asset `kUserGuideAsset`
/// (see pubspec.yaml), so it works offline and no longer depends on GitHub being reachable. The
/// body is [UserGuideView]: a WebView on iOS/Android and an `<iframe>` on web, because
/// webview_flutter has no endorsed web implementation.
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  /// Pushes the guide as a full page, mirroring how `UserGuideActivity` is launched.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const UserGuideScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.userGuide)),
      body: const SafeArea(top: false, child: UserGuideView()),
    );
  }
}
