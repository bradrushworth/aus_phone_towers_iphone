/// Pure builder for the "Report a Problem" email subject, mirroring the Java Android app's
/// `Screenshot.sendMail`, which builds the subject as:
///
///   "Aus Phone Towers Problem Report: " + Build.MODEL + ", " + androidId + ", v" +
///   BuildConfig.VERSION_NAME
///
/// Kept side-effect-free (no platform channels, no BuildContext) so it's unit-testable — see
/// `test/helpers/problem_report_helper_test.dart`. The device model/id and app version/build
/// are gathered on the platform side (device_info_plus / package_info_plus) and passed in here,
/// then the built subject is sent across the screenshot method channel to the native mail
/// composer, so this is the single source of truth for the subject's format on both platforms.
class ProblemReportHelper {
  static const String _prefix = 'Aus Phone Towers Problem Report';

  /// Builds the subject line. Any missing/blank piece (model, deviceId, version) is simply
  /// omitted — never rendered as the literal string "null", and never leaving a stray leading
  /// comma or separator behind.
  ///
  /// [version] and [buildNumber] are combined as `"v" + version + "+" + buildNumber` (matching
  /// pubspec.yaml's "7.7.48+331" version format), falling back to just `"v" + version` if
  /// there's no build number, and omitted entirely if there's no version.
  static String buildSubject({
    String? model,
    String? deviceId,
    String? version,
    String? buildNumber,
  }) {
    final List<String> parts = <String>[];

    if (model != null && model.trim().isNotEmpty) {
      parts.add(model.trim());
    }
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      parts.add(deviceId.trim());
    }

    final String? versionPart = _buildVersionPart(version, buildNumber);
    if (versionPart != null) {
      parts.add(versionPart);
    }

    if (parts.isEmpty) {
      return _prefix;
    }
    return '$_prefix: ${parts.join(', ')}';
  }

  static String? _buildVersionPart(String? version, String? buildNumber) {
    final String? trimmedVersion =
        (version != null && version.trim().isNotEmpty) ? version.trim() : null;
    if (trimmedVersion == null) return null;

    final String? trimmedBuild =
        (buildNumber != null && buildNumber.trim().isNotEmpty) ? buildNumber.trim() : null;
    if (trimmedBuild == null) return 'v$trimmedVersion';
    return 'v$trimmedVersion+$trimmedBuild';
  }
}
