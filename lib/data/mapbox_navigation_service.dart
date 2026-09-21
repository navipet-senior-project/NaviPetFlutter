import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'navigation_models.dart';
import 'outdoor_route_gateway.dart';

class MapboxNavigationService implements OutdoorRouteGateway {
  static const _requestTimeout = Duration(seconds: 12);

  MapboxNavigationService({required this.accessToken, http.Client? client})
    : _client = client ?? http.Client();

  final String accessToken;
  final http.Client _client;
  String _sessionToken = _newSessionToken();

  bool get isConfigured => accessToken.trim().isNotEmpty;

  Future<List<PlaceSuggestion>> suggestPlaces(
    String query, {
    NavigationCoordinate? proximity,
  }) async {
    if (query.trim().length < 2) return const [];
    _ensureConfigured();

    final parameters = <String, String>{
      'q': query.trim(),
      'language': 'en',
      'country': 'US',
      'limit': '8',
      'session_token': _sessionToken,
      'access_token': accessToken,
      if (proximity != null)
        'proximity': '${proximity.longitude},${proximity.latitude}',
    };
    final response = await _client
        .get(
          Uri.https(
            'api.mapbox.com',
            '/search/searchbox/v1/suggest',
            parameters,
          ),
        )
        .timeout(_requestTimeout);
    final body = _decodeResponse(response);
    final suggestions = body['suggestions'] as List<dynamic>? ?? const [];

    return suggestions
        .map((value) {
          final item = value as Map<String, dynamic>;
          return PlaceSuggestion(
            mapboxId: item['mapbox_id']?.toString() ?? '',
            name: (item['name_preferred'] ?? item['name'] ?? 'Destination')
                .toString(),
            description:
                (item['full_address'] ??
                        item['place_formatted'] ??
                        item['address'] ??
                        '')
                    .toString(),
          );
        })
        .where((item) => item.mapboxId.isNotEmpty)
        .toList();
  }

  Future<NaviDestination> retrievePlace(PlaceSuggestion suggestion) async {
    _ensureConfigured();
    final response = await _client
        .get(
          Uri.https(
            'api.mapbox.com',
            '/search/searchbox/v1/retrieve/${suggestion.mapboxId}',
            {'session_token': _sessionToken, 'access_token': accessToken},
          ),
        )
        .timeout(_requestTimeout);
    final body = _decodeResponse(response);
    final features = body['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) {
      throw const NavigationServiceException('Destination details not found.');
    }

    final feature = features.first as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? const {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];
    if (coordinates.length < 2) {
      throw const NavigationServiceException(
        'Destination coordinates were unavailable.',
      );
    }
    final properties =
        feature['properties'] as Map<String, dynamic>? ?? const {};
    _sessionToken = _newSessionToken();

    return NaviDestination(
      name:
          (properties['name_preferred'] ??
                  properties['name'] ??
                  suggestion.name)
              .toString(),
      address:
          (properties['full_address'] ??
                  properties['place_formatted'] ??
                  suggestion.description)
              .toString(),
      coordinate: NavigationCoordinate(
        longitude: (coordinates[0] as num).toDouble(),
        latitude: (coordinates[1] as num).toDouble(),
      ),
    );
  }

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    String profile = 'walking',
  }) async {
    _ensureConfigured();
    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    final response = await _client
        .get(
          Uri.https(
            'api.mapbox.com',
            '/directions/v5/mapbox/$profile/$coordinates',
            {
              'alternatives': 'false',
              'banner_instructions': 'true',
              'geometries': 'geojson',
              'overview': 'full',
              'steps': 'true',
              'voice_instructions': 'true',
              'voice_units': 'imperial',
              'access_token': accessToken,
            },
          ),
        )
        .timeout(_requestTimeout);
    final body = _decodeResponse(response);
    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw const NavigationServiceException(
        'No walkable route was found for that destination.',
      );
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>? ?? const {};
    final rawCoordinates =
        geometry['coordinates'] as List<dynamic>? ?? const [];
    final routeCoordinates = rawCoordinates.map((value) {
      final pair = value as List<dynamic>;
      return NavigationCoordinate(
        longitude: (pair[0] as num).toDouble(),
        latitude: (pair[1] as num).toDouble(),
      );
    }).toList();

    final steps = <NavigationStep>[];
    final legs = route['legs'] as List<dynamic>? ?? const [];
    for (final legValue in legs) {
      final leg = legValue as Map<String, dynamic>;
      for (final stepValue in leg['steps'] as List<dynamic>? ?? const []) {
        final step = stepValue as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>? ?? const {};
        final location = maneuver['location'] as List<dynamic>? ?? const [];
        if (location.length < 2) continue;
        steps.add(
          NavigationStep(
            instruction: (maneuver['instruction'] ?? 'Continue on the route')
                .toString(),
            distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (step['duration'] as num?)?.toDouble() ?? 0,
            maneuver: NavigationCoordinate(
              longitude: (location[0] as num).toDouble(),
              latitude: (location[1] as num).toDouble(),
            ),
          ),
        );
      }
    }

    return NavigationRoute(
      coordinates: routeCoordinates,
      steps: steps,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw NavigationServiceException(
        'Mapbox returned an invalid response (${response.statusCode}).',
      );
    }
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NavigationServiceException(
        body['message']?.toString() ??
            'Mapbox request failed (${response.statusCode}).',
      );
    }
    return body;
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const NavigationServiceException(
        'MAPBOX_PUBLIC_TOKEN is missing from .env.',
      );
    }
  }

  void dispose() => _client.close();

  static String _newSessionToken() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }
}

class NavigationServiceException implements Exception {
  const NavigationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
