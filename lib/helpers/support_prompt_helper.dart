/// Pure decision logic for the weekly "Support the App" prompt, ported from the Java app's
/// `MapsActivity.maybeShowSupportPrompt()`. Kept side-effect-free (no SharedPreferences, no
/// BuildContext) so it's unit-testable with an injected clock — see
/// `SupportPromptDecision` and `test/helpers/support_prompt_helper_test.dart`.
class SupportPromptHelper {
  static const int kWeekMillis = 7 * 24 * 60 * 60 * 1000;

  /// Decides whether to show the support prompt now, given the last time it was shown (or
  /// null if never shown / first launch) and the current time.
  ///
  /// Mirrors the Java behaviour exactly:
  ///   * First-ever launch (no stored timestamp): seed the timestamp but don't show yet.
  ///   * At least a week since it was last shown: show it, and record the new timestamp.
  ///   * Otherwise: do nothing.
  static SupportPromptDecision decide({
    required int? lastShownMillis,
    required int nowMillis,
  }) {
    if (lastShownMillis == null) {
      return SupportPromptDecision(shouldShow: false, newLastShownMillis: nowMillis);
    }
    if (nowMillis - lastShownMillis >= kWeekMillis) {
      return SupportPromptDecision(shouldShow: true, newLastShownMillis: nowMillis);
    }
    return const SupportPromptDecision(shouldShow: false, newLastShownMillis: null);
  }
}

/// Result of [SupportPromptHelper.decide]. [newLastShownMillis] is the timestamp the caller
/// should persist, or null if nothing needs to be written.
class SupportPromptDecision {
  final bool shouldShow;
  final int? newLastShownMillis;

  const SupportPromptDecision({required this.shouldShow, required this.newLastShownMillis});
}
