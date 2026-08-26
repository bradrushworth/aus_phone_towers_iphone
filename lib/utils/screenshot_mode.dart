/// True when the app is running under the store-screenshot integration test.
///
/// Set by `codemagic.yaml` -> `screenshots-workflow`, which passes
/// `--dart-define=SCREENSHOT_MODE=true` to `flutter drive`. It is a compile-time constant, so
/// in every released build this is `false` and every `if (kScreenshotMode)` branch below is
/// removed entirely by the compiler. Nothing about the shipped app changes.
///
/// It exists because a screenshot run is not a normal launch, and two things that are correct
/// for a real user are wrong for it:
///
///  * **The App Tracking Transparency prompt** is a system modal whose future never completes
///    until a human taps it. On CI nobody will, so `main()` never reaches `runApp()` and the app
///    renders nothing at all — no crash, no exception, just an app that never starts.
///  * **Ads.** `flutter drive` builds debug, and the debug branch deliberately uses Google's
///    TEST ad unit. That renders "You've loaded a test ad from AdMob. Way to go!" behind a
///    "Test mode" badge across the bottom of the screen — published straight onto the store
///    listing if nobody looks at the PNG.
///
/// Both are invisible in the build log. The first is caught by the screenshot test asserting a
/// MaterialApp actually painted; the second is only ever caught by a human looking at the image,
/// which is why this constant exists rather than a cleverer runtime check.
const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');
