import 'package:flutter/material.dart';
import 'package:phonetowers/helpers/telco_helper.dart';

/// F3 (UI overhaul port): the map legend, opened from the persistent "ⓘ Legend" chip. Explains
/// the pin colours (one per carrier), the coverage shading and its contour labels, and the
/// marker types. (The Android app's timing-advance ring and direction-line entries don't apply —
/// iOS and web expose no cell identity, so there is no serving-tower overlay to explain.
/// Selection dimming is likewise Android-only: Flutter coverage is per-tap and already replaced
/// on the next tap unless Multi-Tower Coverage is on.)
class LegendSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (bc) {
        final onSurface = Theme.of(bc).colorScheme.onSurface;
        final onSurfaceVariant = Theme.of(bc).colorScheme.onSurfaceVariant;

        Widget sectionTitle(String text) => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              child: Text(text.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12, letterSpacing: 0.5, color: onSurfaceVariant)),
            );

        Widget row(Color colour, String label, String sub, {bool outlineOnly = false}) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 12, top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: outlineOnly ? Colors.transparent : colour,
                      border: outlineOnly
                          ? Border.all(color: colour.withValues(alpha: 1), width: 2.5)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(fontSize: 14.5, color: onSurface)),
                        if (sub.isNotEmpty)
                          Text(sub,
                              style:
                                  TextStyle(fontSize: 12, color: onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            );

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(bc).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(bc).size.height * 0.8),
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
              Text('Map legend',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: onSurface)),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('Tower pins · one colour per carrier'),
                      row(TelcoHelper.getColor(Telco.Telstra, 255), 'Telstra', ''),
                      row(TelcoHelper.getColor(Telco.Optus, 255), 'Optus', ''),
                      row(TelcoHelper.getColor(Telco.Vodafone, 255), 'Vodafone', ''),
                      row(TelcoHelper.getColor(Telco.NBN, 255), 'NBN', ''),
                      row(TelcoHelper.getColor(Telco.Other, 255), 'Other licencees', ''),
                      sectionTitle('Coverage shading'),
                      row(TelcoHelper.getColor(Telco.Optus, 90),
                          'Estimated coverage, tinted by carrier',
                          'Deeper colour where coverage overlaps; larger polygons carry more capacity'),
                      row(TelcoHelper.getColor(Telco.Optus, 255), 'Ring labels',
                          '“3510 MHz NR” marks each band\'s ring, drawn to your Signal Strength filter setting',
                          outlineOnly: true),
                      sectionTitle('Markers'),
                      row(const Color(0xFF03A9F4), 'Your location', ''),
                      sectionTitle('Tips'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            'Tap a tower for its details and coverage. Use Map Layers to switch '
                            'map modes, terrain awareness and polygon precision; use the funnel '
                            'to filter carriers, bands and more.',
                            style: TextStyle(fontSize: 13, color: onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
