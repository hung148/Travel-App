import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/money.dart';

/// One conversion factor: 1 [base] buys [rate] of [quote].
class ExchangeRate {
  final String base;
  final String quote;
  final double rate;
  final DateTime fetchedAt;

  const ExchangeRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.fetchedAt,
  });

  double convert(double amount) => amount * rate;

  /// "1 USD = 26,016 VND" - shown to the user so the number that replaced
  /// their budget is never unexplained.
  String get description => '1 $base = ${Money.format(rate, quote)}';
}

/// Fetches daily exchange rates so a currency switch can carry the user's
/// budget across instead of silently reinterpreting it.
///
/// Deliberately narrow: this converts amounts the USER typed (a budget, a
/// hotel rate they entered). Prices published by Google are still used only in
/// their own currency - see `PriceCalibrationService`.
class CurrencyRateService {
  CurrencyRateService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Keyless public endpoint. Daily resolution, which is the right precision
  /// for a travel budget - this is not a trading app.
  static const _endpoint = 'https://open.er-api.com/v6/latest';

  static const _cacheTtl = Duration(hours: 12);
  static const _timeout = Duration(seconds: 10);

  final Map<String, _CachedRates> _cache = <String, _CachedRates>{};

  /// Null when no rate could be obtained. Callers must handle that rather than
  /// falling back to 1.0, which would silently claim two currencies are worth
  /// the same.
  Future<ExchangeRate?> rate({
    required String from,
    required String to,
  }) async {
    final base = Money.normalize(from);
    final quote = Money.normalize(to);

    if (base == quote) {
      return ExchangeRate(
        base: base,
        quote: quote,
        rate: 1,
        fetchedAt: DateTime.now(),
      );
    }

    final rates = await _ratesFor(base);
    final value = rates?[quote];
    if (value == null || !value.isFinite || value <= 0) return null;

    return ExchangeRate(
      base: base,
      quote: quote,
      rate: value,
      fetchedAt: DateTime.now(),
    );
  }

  Future<Map<String, double>?> _ratesFor(String base) async {
    final cached = _cache[base];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.rates;
    }

    try {
      final response = await _client
          .get(Uri.parse('$_endpoint/$base'))
          .timeout(_timeout);
      if (response.statusCode != 200) return cached?.rates;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return cached?.rates;
      if (data['result'] != 'success') return cached?.rates;

      final raw = data['rates'];
      if (raw is! Map) return cached?.rates;

      final parsed = <String, double>{};
      raw.forEach((key, value) {
        final amount = value is num ? value.toDouble() : null;
        if (amount != null && amount.isFinite && amount > 0) {
          parsed[key.toString().toUpperCase()] = amount;
        }
      });
      if (parsed.isEmpty) return cached?.rates;

      _cache[base] = _CachedRates(rates: parsed, fetchedAt: DateTime.now());
      return parsed;
    } catch (_) {
      // Offline, blocked, or malformed. A stale cached rate still beats
      // refusing to convert; null means we genuinely have nothing.
      return cached?.rates;
    }
  }

  void dispose() => _client.close();
}

class _CachedRates {
  final Map<String, double> rates;
  final DateTime fetchedAt;

  const _CachedRates({required this.rates, required this.fetchedAt});
}
