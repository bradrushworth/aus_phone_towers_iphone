/// Mirrors the Android app's `utilities/MotionPreferences` (Phase 7 of the UI overhaul, PR
/// java#107): a one-shot camera "fly to" — the search-result tap in
/// `ui/widgets/search_sheet.dart` — should animate normally but jump instantly when the system's
/// reduce-motion setting is on. Flutter surfaces that setting as
/// `MediaQuery.of(context).disableAnimations`; this class turns it into a camera-update decision
/// so the decision itself is testable without a widget tree. Continuous camera movement (Follow
/// GPS / Driving Mode) is deliberately not gated on this, matching the Android app: it re-triggers
/// on every location fix rather than being a one-shot transition.
class CameraMotion {
  CameraMotion._();

  /// True when a one-shot camera transition should skip its animation and jump straight there.
  /// [disableAnimations] is `MediaQuery.of(context).disableAnimations` — Flutter's system
  /// reduce-motion signal, on by iOS's "Reduce Motion", Android's "Remove animations", and the
  /// equivalent browser/OS setting on web.
  static bool shouldSkipAnimation({required bool disableAnimations}) =>
      disableAnimations;
}
