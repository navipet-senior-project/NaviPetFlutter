import 'dart:convert';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/app_theme.dart';
import 'navigation_models.dart';

/// Stable style identities prevent duplicate layers across selection and reloads.
class BuildingHighlight {
  BuildingHighlight(this.style);
  static const sourceId = 'navipet-selected-building';
  static const fillId = 'navipet-selected-building-fill';
  static const outlineId = 'navipet-selected-building-outline';
  static const opacity = 0.25;
  final StyleManager style;
  BuildingFootprint? _footprint;
  String? _appliedData;
  Future<void> _work = Future.value();

  Future<void> show(BuildingFootprint? footprint) {
    _footprint = footprint;
    return _queue();
  }

  Future<void> restore() {
    _appliedData = null;
    return _queue();
  }

  Future<void> _queue() {
    final next = _work.then((_) => _apply());
    _work = next.catchError((Object _) {});
    return next;
  }

  Future<void> _apply() async {
    final footprint = _footprint;
    if (footprint == null) {
      for (final id in [outlineId, fillId]) {
        if (await style.styleLayerExists(id)) await style.removeStyleLayer(id);
      }
      if (await style.styleSourceExists(sourceId)) {
        await style.removeStyleSource(sourceId);
      }
      _appliedData = null;
      return;
    }
    final data = jsonEncode({
      'type': 'Feature',
      'properties': <String, Object>{},
      'geometry': footprintToGeoJson(footprint),
    });
    if (!await style.styleSourceExists(sourceId)) {
      await style.addSource(GeoJsonSource(id: sourceId, data: data));
    } else if (_appliedData != data) {
      await style.setStyleSourceProperty(sourceId, 'data', data);
    }
    _appliedData = data;
    if (!await style.styleLayerExists(fillId)) {
      await style.addLayer(
        FillLayer(
          id: fillId,
          sourceId: sourceId,
          fillColor: AppColors.amber.toARGB32(),
          fillOpacity: opacity,
        ),
      );
    }
    if (!await style.styleLayerExists(outlineId)) {
      await style.addLayer(
        LineLayer(
          id: outlineId,
          sourceId: sourceId,
          lineColor: AppColors.amber.toARGB32(),
          lineWidth: 2.5,
        ),
      );
    }
  }
}
