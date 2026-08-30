import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Upper bound on the number of [Marker]s we ever hand to the platform GoogleMap
/// widget in one go.
///
/// The Google Maps iOS SDK keeps every registered marker icon in a single texture
/// atlas. The google_maps_flutter plugin decodes a fresh `UIImage` per marker —
/// even for markers with `visible: false` — and once the atlas fills up, iOS starts
/// handing back corrupted/clipped icon textures for markers already on screen
/// (see GitHub issue #58, and the upstream report at flutter/flutter#172909).
/// Android and web don't share this limitation, but a single bound keeps the
/// behaviour predictable everywhere and keeps the marker set small regardless of
/// platform.
///
/// `SiteHelper.globalListMapOverlay` grows unboundedly as the user pans (every
/// tower ever downloaded stays in memory), so something has to cap what actually
/// reaches the map. 700 is comfortably under where the atlas has been observed to
/// start failing, while still being generous enough to cover a dense urban view.
const int kMaxPlatformMarkers = 700;

/// Selects the subset of [markers] that should actually be handed to the platform
/// GoogleMap widget, bounding the result to at most [cap] markers.
///
/// This exists purely to work around the iOS marker-texture-atlas exhaustion bug
/// described on [kMaxPlatformMarkers] (issue #58 / flutter/flutter#172909): our
/// app accumulates every site and label marker it has ever downloaded, but the
/// platform view only ever needs to render what's near the current viewport.
///
/// Filtering rules, applied in order:
///  1. Null markers are dropped (call sites build `Set<Marker>` from nullable
///     `MapOverlay.marker` fields).
///  2. Markers with `visible == false` are dropped entirely — the iOS plugin still
///     decodes and registers an icon `UIImage` for a hidden marker, so keeping
///     them around contributes to atlas exhaustion for zero visual benefit.
///  3. If [center] is null (e.g. camera position not yet known), the first [cap]
///     surviving markers are kept, in iteration order — there's no viewport to
///     filter against yet, so we just enforce the cap.
///  4. Otherwise, only markers within a lat/lon bounding box around [center] are
///     kept. The half-span (in degrees, used for both latitude and longitude) is
///     `360.0 * 1.5 / pow(2, zoom)` — roughly 1.5 screen-widths on each side of the
///     centre at typical phone widths, at the given [zoom]. Using the same span
///     for latitude deliberately over-covers the vertical extent (longitude
///     degrees shrink towards the poles, latitude degrees don't) — that's cheap,
///     safe, and simpler than accounting for aspect ratio or projection.
///  5. [zoom] is clamped to a minimum of 3 before computing the span, so a very
///     zoomed-out camera (e.g. zoom 0) doesn't select a box the size of the whole
///     country and defeat the point of filtering.
///  6. If more than [cap] markers survive the box filter, only the [cap] nearest
///     to [center] are kept, ranked by squared degree distance (no trig needed —
///     we only need a consistent ordering, not an accurate physical distance).
///
/// Returns a [Set<Marker>], matching what the GoogleMap widget's `markers`
/// parameter expects.
Set<Marker> selectMarkersForViewport(
  Iterable<Marker?> markers, {
  required LatLng? center,
  required double zoom,
  int cap = kMaxPlatformMarkers,
}) {
  final List<Marker> visible = <Marker>[];
  for (final Marker? marker in markers) {
    if (marker == null) continue;
    if (!marker.visible) continue;
    visible.add(marker);
  }

  if (center == null) {
    return visible.take(cap).toSet();
  }

  final double clampedZoom = zoom < 3 ? 3 : zoom;
  final double halfSpan = 360.0 * 1.5 / pow(2, clampedZoom);

  final double minLat = center.latitude - halfSpan;
  final double maxLat = center.latitude + halfSpan;
  final double minLng = center.longitude - halfSpan;
  final double maxLng = center.longitude + halfSpan;

  final List<Marker> inBox = visible.where((Marker marker) {
    final LatLng position = marker.position;
    return position.latitude >= minLat &&
        position.latitude <= maxLat &&
        position.longitude >= minLng &&
        position.longitude <= maxLng;
  }).toList();

  if (inBox.length <= cap) {
    return inBox.toSet();
  }

  double squaredDistance(Marker marker) {
    final double dLat = marker.position.latitude - center.latitude;
    final double dLng = marker.position.longitude - center.longitude;
    return dLat * dLat + dLng * dLng;
  }

  inBox.sort((Marker a, Marker b) => squaredDistance(a).compareTo(squaredDistance(b)));

  return inBox.take(cap).toSet();
}
