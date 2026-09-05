/// Currency formatting for plan costs.
///
/// Works with any ISO 4217 code: known codes get their symbol, everything else
/// renders as "1,234 XYZ". Amounts are always whole units - trip planning has
/// no use for cents, and fake precision is the problem this change set exists
/// to remove.
class Money {
  const Money._();

  static const defaultCurrencyCode = 'USD';

  static const _symbols = <String, String>{
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'KRW': '₩',
    'INR': '₹',
    'VND': '₫',
    'THB': '฿',
    'PHP': '₱',
    'RUB': '₽',
    'TRY': '₺',
    'ILS': '₪',
    'NGN': '₦',
    'UAH': '₴',
    'KZT': '₸',
    'LAK': '₭',
    'KHR': '៛',
    'MNT': '₮',
    'BDT': '৳',
    'CRC': '₡',
    'PYG': '₲',
    'GEL': '₾',
    'AZN': '₼',
    'PLN': 'zł',
    'CZK': 'Kč',
    'HUF': 'Ft',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'ISK': 'kr',
    'CHF': 'CHF',
    'BRL': 'R\$',
    'MXN': 'MX\$',
    'ARS': 'AR\$',
    'CLP': 'CLP\$',
    'COP': 'COP\$',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'NZD': 'NZ\$',
    'SGD': 'S\$',
    'HKD': 'HK\$',
    'TWD': 'NT\$',
    'MYR': 'RM',
    'IDR': 'Rp',
    'ZAR': 'R',
    'MMK': 'K',
    'LKR': 'Rs',
    'NPR': 'Rs',
    'PKR': 'Rs',
    'EGP': 'E£',
    'MAD': 'MAD',
    'AED': 'AED',
    'SAR': 'SAR',
    'QAR': 'QAR',
  };

  /// Codes conventionally written after the amount rather than before it.
  static const _suffixCodes = <String>{
    'VND',
    'PLN',
    'CZK',
    'HUF',
    'SEK',
    'NOK',
    'DKK',
    'ISK',
    'LAK',
    'KHR',
    'MNT',
    'RON',
    'BGN',
  };

  static final _codePattern = RegExp(r'^[A-Z]{3}$');

  static bool isValidCode(String? code) =>
      _codePattern.hasMatch((code ?? '').trim().toUpperCase());

  /// Any unrecognised or malformed code falls back to [defaultCurrencyCode]
  /// rather than throwing, so a bad Firestore value can never crash a plan.
  static String normalize(String? code) {
    final value = (code ?? '').trim().toUpperCase();
    return isValidCode(value) ? value : defaultCurrencyCode;
  }

  /// The label for a text-field prefix. Falls back to the code itself, which
  /// is a perfectly good label for a currency we have no glyph for.
  static String symbolFor(String? code) {
    final normalized = normalize(code);
    return _symbols[normalized] ?? normalized;
  }

  static String format(double amount, String? currencyCode) {
    final code = normalize(currencyCode);
    final rounded = amount.isFinite ? amount.round() : 0;
    final body = _group(rounded.abs());
    final sign = rounded < 0 ? '-' : '';
    final symbol = _symbols[code];

    if (symbol == null) return '$sign$body $code';
    if (_suffixCodes.contains(code)) return '$sign$body$symbol';
    return '$sign$symbol$body';
  }

  /// "₫120,000–300,000". Collapses to a single amount when the bounds are
  /// within one whole unit of each other.
  static String formatRange(double low, double high, String? currencyCode) {
    if (high - low < 1) return format(low, currencyCode);
    return '${format(low, currencyCode)}–${format(high, currencyCode)}';
  }

  /// Rounds a converted amount to something a person would actually type.
  ///
  /// A budget is a decision, not an invoice: after converting \$2,000 into
  /// dong, "₫52,031,337" is worse than "₫52,000,000" in every way that
  /// matters. The step scales with magnitude so it works for yen and dong as
  /// well as for dollars.
  static double roundBudget(double amount) {
    if (!amount.isFinite || amount <= 0) return 0;

    final step = switch (amount) {
      >= 10000000 => 100000.0,
      >= 1000000 => 10000.0,
      >= 100000 => 1000.0,
      >= 10000 => 100.0,
      >= 1000 => 10.0,
      >= 100 => 5.0,
      _ => 1.0,
    };

    final rounded = (amount / step).round() * step;
    return rounded <= 0 ? step : rounded;
  }

  static String _group(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}
