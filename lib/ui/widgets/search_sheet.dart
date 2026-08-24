import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/ui/map_common.dart';

/// F6 (UI overhaul port): search that answers. Matched sites appear in a bottom sheet ranked
/// nearest-first (name · state/postcode · distance); tapping a row downloads that tile, moves the
/// camera there and opens the site sheet once the tile lands. Inline empty state and
/// recent-search rows (last 10) replace the old fly-to-Australia pipeline.
class SearchSheet {
  static const int _siteSheetWaitMs = 2500; // tile download grace before opening the site sheet

  /// Returns a Future (never `async void`): an `async void` body would send any failure to the
  /// zone as an unhandled error that the caller cannot catch.
  static Future<void> show(
      BuildContext context,
      String query,
      List<SearchResult> results,
      void Function(String geoHash, bool expandGeohash) downloadTowers,
      dynamic mapController) async {
    List<String> recents = const [];
    try {
      recents = List<String>.from(await SearchHelper.getRecentSearches());
    } catch (_) {
      // Recent searches are a convenience; never let them block the results.
    }
    recents.remove(query);
    if (!context.mounted) return;

    // Drop focus before the modal opens. The search field still holds focus when results arrive,
    // and Flutter marks the content behind a modal aria-hidden — the browser then warns
    // "Blocked aria-hidden on an element because its descendant retained focus".
    FocusManager.instance.primaryFocus?.unfocus();

    // Rank nearest-first from the current camera position.
    final LatLng? here = MapBodyState.currentInstance?.lastCameraPosition?.target;
    if (here != null) {
      results.sort((a, b) => _distanceM(here, a).compareTo(_distanceM(here, b)));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (bc) {
        final onSurface = Theme.of(bc).colorScheme.onSurface;
        final onSurfaceVariant = Theme.of(bc).colorScheme.onSurfaceVariant;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(bc).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(bc).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(bc).colorScheme.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Text('Search',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: onSurface)),
              Text(
                  results.isEmpty
                      ? 'No sites match “$query”'
                      : '${results.length} site${results.length == 1 ? '' : 's'} match “$query”'
                          '${results.length >= 50 ? ' (first 50)' : ''}',
                  style: TextStyle(fontSize: 13, color: onSurfaceVariant)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                            'Try part of a street name, a suburb, or a 4-digit postcode.',
                            style: TextStyle(fontSize: 14, color: onSurfaceVariant)),
                      ),
                    for (final r in results)
                      InkWell(
                        onTap: () => _onResultTapped(bc, r, downloadTowers, mapController),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name.isEmpty ? 'Site ${r.siteId}' : r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: onSurface)),
                              Text(
                                  '${r.state}${r.postcode.isEmpty ? '' : ' ${r.postcode}'}'
                                  '${here != null ? '  ·  ${_formatDistance(_distanceM(here, r))} away' : ''}',
                                  style:
                                      TextStyle(fontSize: 12.5, color: onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    if (recents.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 2),
                        child: Text('RECENT SEARCHES',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: onSurfaceVariant)),
                      ),
                      for (final recent in recents)
                        InkWell(
                          onTap: () {
                            Navigator.of(bc).pop();
                            MapBodyState.currentInstance
                                ?.handleSearchQuery(mapController, recent);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(recent,
                                style: TextStyle(fontSize: 14.5, color: onSurface)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _onResultTapped(
      BuildContext sheetContext,
      SearchResult r,
      void Function(String geoHash, bool expandGeohash) downloadTowers,
      dynamic mapController) {
    Navigator.of(sheetContext).pop();
    if (r.geohash.isNotEmpty) {
      downloadTowers(r.geohash, false);
    }
    final target = LatLng(r.latitude, r.longitude);
    if (!MapBodyState.lockMap && mapController != null) {
      mapController.moveCamera(CameraUpdate.newLatLngZoom(target, 15));
    }
    // Open the site sheet once the tile has had a moment to land; quietly skip if it hasn't.
    Future.delayed(const Duration(milliseconds: _siteSheetWaitMs), () {
      final state = MapBodyState.currentInstance;
      if (state == null || !state.mounted) return;
      for (final overlay in SiteHelper.globalListMapOverlay) {
        final site = overlay.site;
        if (site != null && '${site.siteId}' == r.siteId) {
          state.showCustomInfoWindowAsBottomSheet(state.context, site);
          return;
        }
      }
    });
  }

  // Equirectangular approximation — fine at search-result scales.
  static double _distanceM(LatLng here, SearchResult r) {
    const double earthRadius = 6371000;
    final double dLat = _rad(r.latitude - here.latitude);
    final double dLng = _rad(r.longitude - here.longitude) *
        math.cos(_rad((r.latitude + here.latitude) / 2));
    return earthRadius * math.sqrt(dLat * dLat + dLng * dLng);
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static String _formatDistance(double metres) {
    if (metres >= 10000) return '${(metres / 1000).round()}km';
    if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)}km';
    return '${metres.round()}m';
  }
}
