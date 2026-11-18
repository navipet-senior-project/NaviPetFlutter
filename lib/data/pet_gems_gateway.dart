import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_token_provider.dart';

class PetCostume {
  const PetCostume({
    required this.id,
    required this.name,
    required this.price,
    required this.assetReference,
    required this.owned,
  });

  final String id;
  final String name;
  final int price;
  final String assetReference;
  final bool owned;

  factory PetCostume.fromJson(Map<String, dynamic> json) => PetCostume(
    id: json['id'] as String,
    name: json['name'] as String,
    price: (json['price'] as num).toInt(),
    assetReference: json['assetReference'] as String,
    owned: json['owned'] as bool,
  );
}

class PetWallet {
  const PetWallet(this.balance, this.equippedOutfit, this.ownedOutfits);
  final int balance;
  final String? equippedOutfit;
  final Set<String> ownedOutfits;

  factory PetWallet.fromJson(Map<String, dynamic> json) => PetWallet(
    (json['balance'] as num).toInt(),
    json['equippedOutfit'] as String?,
    (json['ownedOutfits'] as List).cast<String>().toSet(),
  );
}

class PetGemsException implements Exception {
  const PetGemsException(this.message, this.statusCode, {this.shortfall});
  final String message;
  final int statusCode;
  final int? shortfall;
  @override
  String toString() =>
      shortfall == null ? message : '$message ($shortfall more gems needed)';
}

abstract interface class PetGemsGateway {
  Future<PetWallet> getGems();
  Future<List<PetCostume>> getCostumes();
  Future<PetWallet> buy(String outfitId, {bool equip = false});
  Future<PetWallet> equip(String outfitId);
  Future<int> claimDailyLogin();
  Future<String> startNavigation(
    String destinationId,
    double latitude,
    double longitude,
  );
  Future<int> finishNavigation(
    String tripId,
    double latitude,
    double longitude,
  );
}

class HttpPetGemsGateway implements PetGemsGateway {
  HttpPetGemsGateway({
    required String baseUrl,
    required AuthTokenProvider auth,
    http.Client? client,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       // ignore: prefer_initializing_formals
       _auth = auth,
       _client = client ?? http.Client();

  final String _baseUrl;
  final AuthTokenProvider _auth;
  final http.Client _client;

  @override
  Future<PetWallet> getGems() =>
      _request('GET', '/pet/gems', PetWallet.fromJson);

  @override
  Future<List<PetCostume>> getCostumes() async {
    return _request(
      'GET',
      '/pet/costumes',
      (data) => (data['costumes'] as List)
          .map((item) => PetCostume.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<PetWallet> buy(String outfitId, {bool equip = false}) async {
    return _request(
      'POST',
      '/pet/costumes/buy',
      _balanceOnly,
      body: {'outfitId': outfitId, 'equip': equip},
    );
  }

  @override
  Future<PetWallet> equip(String outfitId) async {
    return _request(
      'POST',
      '/pet/costumes/equip',
      _balanceOnly,
      body: {'outfitId': outfitId},
    );
  }

  @override
  Future<int> claimDailyLogin() async {
    return _request(
      'POST',
      '/pet/rewards/daily-login',
      (data) => (data['earned'] as num).toInt(),
    );
  }

  @override
  Future<String> startNavigation(
    String destinationId,
    double latitude,
    double longitude,
  ) async {
    return _request(
      'POST',
      '/pet/rewards/navigation/start',
      (data) => data['tripId'] as String,
      body: {
        'destinationId': destinationId,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  @override
  Future<int> finishNavigation(
    String tripId,
    double latitude,
    double longitude,
  ) async {
    return _request(
      'POST',
      '/pet/rewards/navigation/finish',
      (data) => (data['earned'] as num).toInt(),
      body: {'tripId': tripId, 'latitude': latitude, 'longitude': longitude},
    );
  }

  // buy/equip answer with the balance and equipped outfit only.
  static PetWallet _balanceOnly(Map<String, dynamic> data) => PetWallet(
    (data['balance'] as num).toInt(),
    data['equippedOutfit'] as String?,
    const {},
  );

  Future<T> _request<T>(
    String method,
    String path,
    T Function(Map<String, dynamic> data) parse, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> send(bool refresh) async {
      final token = await _auth.token(forceRefresh: refresh);
      if (token == null || token.isEmpty) {
        throw const PetGemsException('Sign in to use pet gems.', 401);
      }
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          if (body != null) 'Content-Type': 'application/json',
        });
      if (body != null) request.body = jsonEncode(body);
      try {
        return await _client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        throw const PetGemsException(
          'The pet server timed out. Try again.',
          408,
        );
      } on http.ClientException {
        throw const PetGemsException('Could not reach the pet server.', 0);
      }
    }

    var response = await send(false);
    if (response.statusCode == 401) response = await send(true);
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PetGemsException(
        'The pet server returned an invalid response.',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'];
      final details = error is Map ? error['details'] : null;
      final shortfall = error is Map
          ? error['shortfall'] ?? (details is Map ? details['shortfall'] : null)
          : null;
      throw PetGemsException(
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'Pet request failed.',
        response.statusCode,
        shortfall: shortfall is num ? shortfall.toInt() : null,
      );
    }
    try {
      return parse(data);
    } catch (_) {
      throw PetGemsException(
        'The pet server returned an invalid response.',
        response.statusCode,
      );
    }
  }
}
