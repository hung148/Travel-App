import 'dart:convert';

import 'package:http/http.dart' as http;

import '../planner/shopping_vetter.dart';

/// Asks the vetShoppingPlaces endpoint whether shopping candidates are really
/// shopping destinations.
///
/// Google's place types are written by business owners, so a shophouse selling
/// robot vacuums can arrive typed `shopping_mall` with nothing else to give it
/// away. Its NAME gives it away, and reading a Vietnamese business name is a
/// job for a model, not a type rule.
///
/// Every path through this class fails open: no endpoint, no token, a timeout,
/// a bad status, unparseable JSON, or a place the server said nothing about,
/// and the candidate is kept. An empty shopping plan is a much worse bug than
/// one questionable stop.
class ShoppingVettingService implements ShoppingVetter {
  ShoppingVettingService({
    required this.endpoint,
    this.idTokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final String endpoint;

  /// Supplies the Firebase id token. The endpoint requires a signed-in user,
  /// same as the trip AI.
  final Future<String?> Function()? idTokenProvider;

  final Duration timeout;
  final http.Client _client;

  @override
  Future<Set<String>> approve(List<ShoppingCandidate> candidates) async {
    final everything = candidates
        .map((candidate) => candidate.placeId)
        .toSet();
    if (endpoint.trim().isEmpty || candidates.isEmpty) return everything;

    String? idToken;
    try {
      idToken = await idTokenProvider?.call();
    } on Exception {
      return everything;
    }

    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              if (idToken != null && idToken.isNotEmpty)
                'Authorization': 'Bearer $idToken',
            },
            body: utf8.encode(
              jsonEncode({
                'places': candidates
                    .map((candidate) => candidate.toJson())
                    .toList(),
              }),
            ),
          )
          .timeout(timeout);
    } on Exception {
      return everything;
    }

    if (response.statusCode != 200) return everything;

    final Map<String, dynamic> body;
    try {
      body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on Exception {
      return everything;
    } on TypeError {
      return everything;
    }

    final verdicts = body['verdicts'];
    if (verdicts is! Map) return everything;

    // Keep a place unless the server explicitly said it is not a shopping
    // destination. Anything it stayed silent about survives.
    final approved = <String>{};
    for (final placeId in everything) {
      final verdict = verdicts[placeId];
      if (verdict is bool && !verdict) continue;
      approved.add(placeId);
    }
    return approved;
  }
}
