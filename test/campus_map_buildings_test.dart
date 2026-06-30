import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_eats_driver/core/map/campus_map.dart';
import 'package:uni_eats_driver/core/map/udst_building_footprints.dart';

void main() {
  group('UDST dark-mode building polygons', () {
    test('dark mode produces a visible polygon for every footprint', () {
      final polys = udstDarkBuildingPolygons(isDark: true);

      // One polygon per real OSM footprint — buildings WILL be handed to the map.
      expect(polys, isNotEmpty);
      expect(polys.length, udstBuildingFootprints.length);
      expect(polys.length, greaterThanOrEqualTo(50));

      for (final p in polys) {
        // Each polygon is a real closed shape (>= 3 vertices).
        expect(p.points.length, greaterThanOrEqualTo(3));
        // Fill is light slate, clearly lighter than the #242f3e Night base,
        // and partially translucent so labels show through.
        expect(p.fillColor, const Color(0xCC44566B));
        expect(p.fillColor.alpha, greaterThan(0)); // actually painted
        expect(p.strokeWidth, greaterThan(0)); // has a visible outline
      }
    });

    test('every vertex sits within the UDST campus bounds', () {
      for (final b in udstBuildingFootprints) {
        for (final pt in b) {
          final lat = pt[0];
          final lng = pt[1];
          expect(lat, inInclusiveRange(25.355, 25.366));
          expect(lng, inInclusiveRange(51.475, 51.487));
        }
      }
    });

    test('light mode draws no polygons (Google native buildings used instead)',
        () {
      expect(udstDarkBuildingPolygons(isDark: false), isEmpty);
    });

    test('polygon ids are unique', () {
      final polys = udstDarkBuildingPolygons(isDark: true);
      final ids = polys.map((p) => p.polygonId.value).toSet();
      expect(ids.length, polys.length);
    });
  });
}
