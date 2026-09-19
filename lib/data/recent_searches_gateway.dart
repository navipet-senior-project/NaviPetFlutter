import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_token_provider.dart';
import 'campus_bounds.dart';
import 'campus_place.dart';
import 'navigation_models.dart';
import 'search_history_store.dart';

abstract interface class RecentSearchesGateway {
  Future<List<CampusPlace>> list();

  Future<void> save(CampusPlace place);

  Future<void> clear();
}

class HttpRecentSearchesGateway implements RecentSearchesGateway {
  HttpRecentSearchesGateway({
    required String baseUrl,
    required AuthTokenProvider auth,
    http.Client? client,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       // ignore: prefer_initializing_formals
       _auth = auth,
       _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  final String baseUrl;
  final AuthTokenProvider _auth;
  final http.Client _client;

  @override
  Future<List<CampusPlace>> list() async {
    final response = await _send('GET', '/recent-searches');
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final results = body['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(CampusPlace.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> save(CampusPlace place) async {
    // Temporary Mapbox results are not storable server-side; campus-only
    // filtering means we should never reach here with one.
    if (place.external) return;
    await _send(
      'POST',
      '/recent-searches',
      body: jsonEncode({'placeId': place.id}),
    );
  }

  @override
  Future<void> clear() => _send('DELETE', '/recent-searches');

  Future<http.Response> _send(
    String method,
    String path, {
    String? body,
  }) async {
    var response = await _attempt(
      method,
      path,
      body: body,
      forceRefresh: false,
    );
    if (response.statusCode == 401) {
      response = await _attempt(method, path, body: body, forceRefresh: true);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CampusSearchException(
        failure: response.statusCode == 401
            ? CampusSearchFailure.unauthorized
            : CampusSearchFailure.api,
        message: 'Recent searches are unavailable.',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  Future<http.Response> _attempt(
    String method,
    String path, {
    String? body,
    required bool forceRefresh,
  }) async {
    final token = await _auth.token(forceRefresh: forceRefresh);
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        if (token != null) 'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = body;

    try {
      final streamed = await _client.send(request).timeout(_timeout);
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const CampusSearchException(
        failure: CampusSearchFailure.offline,
        message: 'Recent searches are offline.',
      );
    } on SocketException {
      throw const CampusSearchException(
        failure: CampusSearchFailure.offline,
        message: 'Recent searches are offline.',
      );
    }
  }
}

/// Serves the server list when it can, the on-device list when it cannot.
///
/// Recents are a convenience: a network failure must never leave the search
/// overlay blank, and it must never block selecting a destination.
class CachedRecentSearches implements RecentSearchesGateway {
  CachedRecentSearches({required this.remote, required this.cache});

  final RecentSearchesGateway remote;
  final SearchHistoryStore cache;

  @override
  Future<List<CampusPlace>> list() async {
    try {
      final places = filterToCampus(await remote.list());
      await _replaceCache(places);
      return places;
    } on Object {
      final cached = (await cache.load())
          .map(_fromDestination)
          .toList(growable: false);
      return filterToCampus(cached);
    }
  }

  @override
  Future<void> save(CampusPlace place) async {
    try {
      await remote.save(place);
    } on Object {
      // Keeping the local copy is more useful than surfacing this failure.
    }
    // External/Mapbox results are not CSULB records; caching one would let it
    // resurface indistinguishably from a real campus result on the next
    // remote failure, defeating campus-only filtering.
    if (place.outdoorDestination != null && !place.external) {
      await cache.add(place.toDestination());
    }
  }

  @override
  Future<void> clear() async {
    try {
      await remote.clear();
    } on Object {
      // Local clear still applies below.
    }
    await cache.clear();
  }

  Future<void> _replaceCache(List<CampusPlace> places) async {
    await cache.clear();
    for (final place in places.reversed) {
      if (place.outdoorDestination == null) continue;
      await cache.add(place.toDestination());
    }
  }

  CampusPlace _fromDestination(NaviDestination destination) => CampusPlace(
    id: destination.id ?? destination.name,
    type: destination.type ?? CampusDestinationType.building,
    title: destination.name,
    subtitle: destination.address,
    source: 'cache',
    buildingCode: destination.buildingCode,
    roomNumber: destination.roomNumber,
    floorNumber: destination.floorNumber,
    outdoorDestination: destination.coordinate,
    indoorDestinationId: destination.indoorDestinationId,
    external: destination.external,
    attribution: destination.attribution,
  );
}
