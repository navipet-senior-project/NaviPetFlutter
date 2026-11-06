import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class FakeStyle extends StyleManager {
  final sources = <String, String>{};
  final layers = <String, Map<String, dynamic>>{};
  var sourceAdds = 0;
  var layerAdds = 0;
  @override
  Future<bool> styleSourceExists(String id) async => sources.containsKey(id);
  @override
  Future<bool> styleLayerExists(String id) async => layers.containsKey(id);
  @override
  Future<void> addStyleSource(String id, String properties) async {
    expect(sources.containsKey(id), isFalse);
    sourceAdds++;
    sources[id] = properties;
  }

  @override
  Future<void> addStyleLayer(String properties, LayerPosition? position) async {
    final layer = jsonDecode(properties) as Map<String, dynamic>;
    final id = layer['id'] as String;
    expect(layers.containsKey(id), isFalse);
    layerAdds++;
    layers[id] = layer;
  }

  @override
  Future<void> setStyleSourceProperty(
    String id,
    String property,
    Object value,
  ) async {
    expect(sources.containsKey(id), isTrue);
    sources[id] = value.toString();
  }

  @override
  Future<void> setStyleSourceProperties(String id, String properties) async {}
  @override
  Future<void> removeStyleLayer(String id) async {
    layers.remove(id);
  }

  @override
  Future<void> removeStyleSource(String id) async {
    sources.remove(id);
  }
}

class FakeLocationSettings implements LocationSettings {
  @override
  Future<void> updateSettings(LocationComponentSettings settings) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMap implements MapboxMap {
  @override
  final FakeStyle style = FakeStyle();
  @override
  final FakeLocationSettings location = FakeLocationSettings();
  List<Point> framed = [];
  @override
  Future<CameraOptions> cameraForCoordinatesPadding(
    List<Point> coordinates,
    CameraOptions camera,
    MbxEdgeInsets? padding,
    double? maxZoom,
    ScreenCoordinate? offset,
  ) async {
    framed = coordinates;
    return camera;
  }

  @override
  Future<void> easeTo(
    CameraOptions camera,
    MapAnimationOptions? animation,
  ) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMarkers implements PointAnnotationManager {
  final annotations = <PointAnnotationOptions>[];
  @override
  Future<void> deleteAll() async {
    annotations.clear();
  }

  @override
  Future<PointAnnotation> create(PointAnnotationOptions options) async {
    annotations.add(options);
    return PointAnnotation(
      id: '${annotations.length}',
      geometry: options.geometry,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLines implements PolylineAnnotationManager {
  @override
  Future<void> deleteAll() async {}
  @override
  Future<PolylineAnnotation> create(PolylineAnnotationOptions options) async =>
      PolylineAnnotation(id: 'route', geometry: options.geometry);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
