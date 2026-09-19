import 'dart:async';

import 'package:flutter/foundation.dart';

import 'campus_bounds.dart';
import 'campus_place.dart';
import 'campus_search_gateway.dart';
import 'navigation_models.dart';
import 'search_location_provider.dart';

enum CampusSearchStatus {
  initial,
  typing,
  loading,
  results,
  noResults,
  offline,
  unauthorized,
  permissionRequired,
  locationUnavailable,
  apiError,
}

class CampusSearchController extends ChangeNotifier {
  CampusSearchController({
    required this.gateway,
    required this.location,
    this.debounce = const Duration(milliseconds: 275),
  });

  final CampusSearchGateway gateway;
  final SearchLocationProvider location;
  final Duration debounce;

  CampusSearchStatus _status = CampusSearchStatus.initial;
  List<CampusPlace> _results = const [];
  String _query = '';
  String? _message;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  CampusSearchStatus get status => _status;
  List<CampusPlace> get results => List.unmodifiable(_results);
  String get query => _query;
  String? get message => _message;

  void queryChanged(String value) {
    _timer?.cancel();
    final generation = ++_generation;
    _query = value;
    _message = null;
    _results = const [];

    final normalized = _normalize(value);
    final meaningfulLength = normalized.replaceAll(' ', '').length;
    if (meaningfulLength == 0) {
      _setStatus(CampusSearchStatus.initial);
      return;
    }
    if (meaningfulLength < 2) {
      _setStatus(CampusSearchStatus.loading);
      return;
    }
    _setStatus(CampusSearchStatus.typing);
    _timer = Timer(
      debounce,
      () => unawaited(_search(value.trim(), normalized, generation)),
    );
  }

  /// Drops the current query and results without disposing. Used when the
  /// signed-in identity changes — this search must not keep showing the
  /// previous user's query or results the next time it's opened.
  void reset() {
    _timer?.cancel();
    _generation++;
    _query = '';
    _message = null;
    _results = const [];
    _setStatus(CampusSearchStatus.initial);
  }

  Future<void> retry() async {
    _timer?.cancel();
    final normalized = _normalize(_query);
    if (normalized.replaceAll(' ', '').length < 2) return;
    final generation = ++_generation;
    await _search(_query.trim(), normalized, generation);
  }

  Future<NaviDestination?> select(CampusPlace suggestion) async {
    final generation = _generation;
    try {
      final selected = suggestion.isLocal
          ? await gateway.place(suggestion.id)
          : suggestion;
      if (!_isCurrent(generation)) return null;
      return selected.toDestination();
    } on CampusSearchException catch (error) {
      if (_isCurrent(generation)) {
        _message = error.message;
        _setStatus(_statusFor(error.failure));
      }
      return null;
    }
  }

  Future<void> _search(
    String requestQuery,
    String normalized,
    int generation,
  ) async {
    if (!_isCurrent(generation)) return;
    _setStatus(CampusSearchStatus.loading);
    try {
      NavigationCoordinate? proximity;
      if (GeolocatorSearchLocationProvider.proximityQueries.contains(
        normalized,
      )) {
        final locationResult = await location.locationFor(normalized);
        if (!_isCurrent(generation)) return;
        switch (locationResult.status) {
          case SearchLocationStatus.permissionRequired:
            _setStatus(CampusSearchStatus.permissionRequired);
            return;
          case SearchLocationStatus.unavailable:
            _setStatus(CampusSearchStatus.locationUnavailable);
            return;
          case SearchLocationStatus.available:
            proximity = locationResult.coordinate;
            break;
          case SearchLocationStatus.notRequired:
            break;
        }
      }

      final found = await gateway.autocomplete(
        requestQuery,
        proximity: proximity,
        limit: 10,
      );
      if (!_isCurrent(generation)) return;
      _results = filterToCampus(found).take(10).toList(growable: false);
      _setStatus(
        _results.isEmpty
            ? CampusSearchStatus.noResults
            : CampusSearchStatus.results,
      );
    } on CampusSearchException catch (error) {
      if (!_isCurrent(generation)) return;
      _message = error.message;
      _results = const [];
      _setStatus(_statusFor(error.failure));
    } on Object catch (error) {
      if (!_isCurrent(generation)) return;
      _message = error.toString();
      _results = const [];
      _setStatus(CampusSearchStatus.apiError);
    }
  }

  static CampusSearchStatus _statusFor(CampusSearchFailure failure) =>
      switch (failure) {
        CampusSearchFailure.offline => CampusSearchStatus.offline,
        CampusSearchFailure.unauthorized => CampusSearchStatus.unauthorized,
        CampusSearchFailure.api => CampusSearchStatus.apiError,
      };

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _setStatus(CampusSearchStatus value) {
    if (_disposed) return;
    _status = value;
    notifyListeners();
  }

  static String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
