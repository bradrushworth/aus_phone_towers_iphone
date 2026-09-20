import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/utils/app_constants.dart';

/// Pins the contract between `docs/user-guide.html` (content, edited by hand) and the app that
/// bundles and renders it (`UserGuideScreen` / `UserGuideView`), which nothing else in the repo
/// checks:
///  * it is declared as a Flutter asset under the exact key the app loads;
///  * it cannot reach the network or run script, because JavaScript is off in the mobile WebView
///    (see user_guide_view_mobile.dart) and the web build's iframe is sandboxed to allow none
///    (see user_guide_view_web.dart) — so the guide must still work with nothing but itself;
///  * every link stays inside the page, so a tap never navigates the guide (or the sandboxed
///    iframe) away to somewhere the user cannot get back from.
///
/// Reads the file with dart:io rather than as a Flutter asset bundle, since plain `flutter test`
/// has no asset bundle — paths are relative to the package root, which is the cwd under
/// `flutter test`.
void main() {
  late String pubspecContent;
  late String html;
  late String lowerHtml;

  setUpAll(() {
    pubspecContent = File('pubspec.yaml').readAsStringSync();
    html = File(kUserGuideAsset).readAsStringSync();
    lowerHtml = html.toLowerCase();
  });

  test('is declared as a Flutter asset under the key the app loads', () {
    expect(kUserGuideAsset, 'docs/user-guide.html');
    expect(File(kUserGuideAsset).existsSync(), isTrue);

    final Iterable<String> trimmedLines =
        pubspecContent.split('\n').map((String line) => line.trim());
    expect(trimmedLines, contains('- docs/user-guide.html'));
  });

  test('is self-contained: no scripts, no remote or embedded resources', () {
    // JavaScript is disabled in the WebView and the web iframe is sandboxed, and the guide must
    // work offline, so none of these — a script, a stylesheet/resource link, an image, a nested
    // frame/plugin, or a CSS url()/@import — may appear.
    const List<String> forbidden = <String>[
      '<script',
      '<link',
      '<img',
      '<iframe',
      '<object',
      '<embed',
      ' src=',
      '@import',
      'url(',
    ];
    for (final String token in forbidden) {
      expect(lowerHtml.contains(token), isFalse, reason: 'guide HTML contains "$token"');
    }
  });

  test('links only to its own anchors, and every anchor exists', () {
    // An external link would navigate the guide page (or the sandboxed iframe, which permits no
    // top-level navigation anyway) away from the guide.
    final RegExp hrefPattern = RegExp(r'href\s*=\s*"([^"]*)"');
    final List<RegExpMatch> matches = hrefPattern.allMatches(html).toList();
    expect(matches, isNotEmpty, reason: 'expected at least one internal link in the guide');

    for (final RegExpMatch match in matches) {
      final String href = match.group(1)!;
      expect(href.startsWith('#'), isTrue, reason: 'non-anchor link: href="$href"');
      final String anchorId = href.substring(1);
      expect(html.contains('id="$anchorId"'), isTrue,
          reason: 'href="$href" has no matching id="$anchorId"');
    }
  });

  test('has a mobile viewport and a title', () {
    expect(lowerHtml.contains('<meta name="viewport"'), isTrue);

    final RegExpMatch? titleMatch = RegExp(r'<title>([^<]*)</title>').firstMatch(html);
    expect(titleMatch, isNotNull, reason: 'expected a <title> element');
    expect(titleMatch!.group(1), contains('User Guide'));
  });
}
