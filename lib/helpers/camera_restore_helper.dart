import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/app_constants.dart';

/// Pure helpers for persisting/restoring the map camera position across
/// backgrounding (see issue #26). Kept free of SharedPreferences /
/// GoogleMapController / State so the decision logic can be unit tested
/// deterministically.

/// Serializes [position] into the single JSON string persisted under
/// `SharedPreferencesHelper.kCameraPosition`. Using one composite key (rather
/// than three independent lat/lng/zoom keys) means the save is a single write,
/// so a process kill mid-flush can't leave the three values inconsistent with
/// each other.
String encodeCameraPosition(CameraPosition position) {
  return jsonEncode(<String, double>{
    'lat': position.target.latitude,
    'lng': position.target.longitude,
    'zoom': position.zoom,
  });
}

/// Decides whether a previously-saved camera position should be restored, and
/// if so, what it is.
///
/// [storedJson] is the raw string previously written by [encodeCameraPosition]
/// (or null/empty if nothing has been saved yet). [followGPSActive] should
/// mirror `MapBodyState.followGPS`: when Follow GPS is on, the live GPS-driven
/// camera should win, so restoring a stale pre-background position would just
/// fight it.
///
/// Returns null when:
/// - Follow GPS is active.
/// - Nothing has been saved yet.
/// - The saved payload is missing/malformed (e.g. truncated by a mid-write kill).
/// - The saved position is the all-zero placeholder and not meaningfully useful.
CameraPosition? resolveRestoredCameraPosition({
  required String? storedJson,
  required bool followGPSActive,
}) {
  if (followGPSActive) return null;
  if (storedJson == null || storedJson.isEmpty) return null;

  try {
    final dynamic decoded = jsonDecode(storedJson);
    if (decoded is! Map) return null;

    final dynamic rawLat = decoded['lat'];
    final dynamic rawLng = decoded['lng'];
    if (rawLat is! num || rawLng is! num) return null;

    final double lat = rawLat.toDouble();
    final double lng = rawLng.toDouble();
    if (lat == 0 && lng == 0) return null;

    final dynamic rawZoom = decoded['zoom'];
    final double zoom = rawZoom is num ? rawZoom.toDouble() : kDefaultZoom;

    return CameraPosition(target: LatLng(lat, lng), zoom: zoom);
  } catch (_) {
    // Malformed/truncated JSON: treat as "nothing usable was saved".
    return null;
  }
}
