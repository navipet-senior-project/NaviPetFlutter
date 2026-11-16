import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/building_highlight.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/navi_map_controller.dart';
import 'package:navipet/data/travel_mode.dart';

import '../tool/osm_test_footprints.dart';
import 'support/mapbox_fakes.dart';

final footprint = validFootprint({
  'type': 'Polygon',
  'coordinates': [
    [
      [0, 0],
      [1, 0],
      [1, 1],
      [0, 1],
      [0, 0],
    ],
  ],
})!;
void main() {
  test(
    'repeated and concurrent selection uses one source and two layers',
    () async {
      final style = FakeStyle();
      final highlight = BuildingHighlight(style);
      await Future.wait([
        highlight.show(footprint),
        highlight.show(footprint),
        highlight.restore(),
      ]);
      expect(style.sources.length, 1);
      expect(style.layers.length, 2);
      expect(style.sourceAdds, 1);
      expect(style.layerAdds, 2);
      final fill = style.layers[BuildingHighlight.fillId]!['paint'] as Map;
      expect(fill['fill-opacity'], BuildingHighlight.opacity);
    },
  );
  test(
    'OSM footprint source keeps the outer ring and courtyard hole',
    () async {
      final style = FakeStyle();
      final highlight = BuildingHighlight(style);
      await highlight.show(osmTestFootprint('College of Business'));
      final feature =
          jsonDecode(style.sources[BuildingHighlight.sourceId]!) as Map;
      final rings = (feature['geometry'] as Map)['coordinates'] as List;
      expect(style.sources, hasLength(1));
      expect(style.layers, hasLength(2));
      expect(rings, hasLength(2));
      expect(rings[0], hasLength(17));
      expect(rings[1], hasLength(5));
    },
  );
  test(
    'style reload restores selected geometry once and clear prevents resurrection',
    () async {
      final style = FakeStyle();
      final highlight = BuildingHighlight(style);
      await highlight.show(footprint);
      style.sources.clear();
      style.layers.clear();
      await Future.wait([highlight.restore(), highlight.restore()]);
      expect(style.sources.length, 1);
      expect(style.layers.length, 2);
      expect(style.sourceAdds, 2);
      expect(style.layerAdds, 4);
      await highlight.show(null);
      await highlight.restore();
      expect(style.sources, isEmpty);
      expect(style.layers, isEmpty);
    },
  );
  test(
    'map controller retains footprint through preview, navigation and reload, and frames building',
    () async {
      final map = FakeMap();
      final markers = FakeMarkers();
      final controller = MapboxNaviMapController(
        map: map,
        routes: FakeLines(),
        markers: markers,
        arrowMarkers: FakeMarkers(),
      );
      const point = NavigationCoordinate(latitude: 0.5, longitude: 0.5);
      final destination = NaviDestination(
        name: 'Test',
        address: '',
        coordinate: point,
        footprint: footprint,
      );
      await controller.showPlace(
        point,
        label: 'Test',
        destination: destination,
        bottomInset: 280,
      );
      expect(map.framed.length, 5);
      expect(map.style.sources.length, 1);
      final sourceAdds = map.style.sourceAdds;
      const route = NavigationRoute(
        coordinates: [point, point],
        steps: [],
        distanceMeters: 10,
        durationSeconds: 10,
      );
      await controller.showRoute(
        RoutePlan(routes: [route], mode: TravelMode.walking),
        origin: point,
        destination: destination,
        bottomInset: 320,
      );
      expect(map.framed.length, 7);
      expect(map.style.sourceAdds, sourceAdds);
      await controller.showGuidance(
        [point, point],
        position: point,
        destination: destination,
      );
      expect(map.style.sourceAdds, sourceAdds);
      map.style.sources.clear();
      map.style.layers.clear();
      await controller.restoreStyle();
      await controller.restoreStyle();
      expect(map.style.sources.length, 1);
      expect(map.style.layers.length, 2);
      await controller.clear();
      expect(map.style.sources, isEmpty);
      await controller.showPlace(
        point,
        label: 'Point',
        bottomInset: 280,
        destination: const NaviDestination(
          name: 'Point',
          address: '',
          coordinate: point,
        ),
      );
      expect(map.style.sources, isEmpty);
      expect(markers.annotations, isNotEmpty);
    },
  );
}
