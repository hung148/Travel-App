import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/money.dart';

class CurrencyOption {
  final String code;
  final String name;

  const CurrencyOption(this.code, this.name);
}

/// A shortlist so the common cases are one tap. Any other ISO 4217 code can
/// still be typed into the search box and used, so this list is convenience,
/// not a limit on which currencies the app supports.
const kCommonCurrencies = <CurrencyOption>[
  CurrencyOption('USD', 'US Dollar'),
  CurrencyOption('EUR', 'Euro'),
  CurrencyOption('GBP', 'British Pound'),
  CurrencyOption('JPY', 'Japanese Yen'),
  CurrencyOption('VND', 'Vietnamese Dong'),
  CurrencyOption('THB', 'Thai Baht'),
  CurrencyOption('SGD', 'Singapore Dollar'),
  CurrencyOption('MYR', 'Malaysian Ringgit'),
  CurrencyOption('IDR', 'Indonesian Rupiah'),
  CurrencyOption('PHP', 'Philippine Peso'),
  CurrencyOption('KRW', 'South Korean Won'),
  CurrencyOption('CNY', 'Chinese Yuan'),
  CurrencyOption('TWD', 'Taiwan Dollar'),
  CurrencyOption('HKD', 'Hong Kong Dollar'),
  CurrencyOption('INR', 'Indian Rupee'),
  CurrencyOption('AUD', 'Australian Dollar'),
  CurrencyOption('NZD', 'New Zealand Dollar'),
  CurrencyOption('CAD', 'Canadian Dollar'),
  CurrencyOption('CHF', 'Swiss Franc'),
  CurrencyOption('SEK', 'Swedish Krona'),
  CurrencyOption('NOK', 'Norwegian Krone'),
  CurrencyOption('DKK', 'Danish Krone'),
  CurrencyOption('PLN', 'Polish Zloty'),
  CurrencyOption('CZK', 'Czech Koruna'),
  CurrencyOption('TRY', 'Turkish Lira'),
  CurrencyOption('AED', 'UAE Dirham'),
  CurrencyOption('SAR', 'Saudi Riyal'),
  CurrencyOption('EGP', 'Egyptian Pound'),
  CurrencyOption('ZAR', 'South African Rand'),
  CurrencyOption('BRL', 'Brazilian Real'),
  CurrencyOption('MXN', 'Mexican Peso'),
  CurrencyOption('ARS', 'Argentine Peso'),
];

class CurrencyField extends StatelessWidget {
  final String code;
  final ValueChanged<String> onChanged;

  /// Supplied by the form so this control matches the fields beside it.
  /// Without it this picked up the theme's stadium button shape while its
  /// neighbours were rounded rectangles.
  final ButtonStyle? style;

  const CurrencyField({
    super.key,
    required this.code,
    required this.onChanged,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = Money.normalize(code);
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDialog<String>(
          context: context,
          builder: (context) => _CurrencyPickerDialog(selected: normalized),
        );
        if (picked != null) onChanged(picked);
      },
      icon: const Icon(Icons.payments_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text('$normalized   ${Money.symbolFor(normalized)}'),
      ),
      style:
          style ??
          OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            alignment: Alignment.centerLeft,
          ),
    );
  }
}

class _CurrencyPickerDialog extends StatefulWidget {
  final String selected;

  const _CurrencyPickerDialog({required this.selected});

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CurrencyOption> get _results {
    final query = _query.trim().toUpperCase();
    if (query.isEmpty) return kCommonCurrencies;
    return kCommonCurrencies
        .where(
          (option) =>
              option.code.contains(query) ||
              option.name.toUpperCase().contains(query),
        )
        .toList();
  }

  /// Lets the user commit a code the shortlist does not carry, e.g. ISK or LAK.
  String? get _customCode {
    final query = _query.trim().toUpperCase();
    if (!Money.isValidCode(query)) return null;
    if (kCommonCurrencies.any((option) => option.code == query)) return null;
    return query;
  }

  @override
  Widget build(BuildContext context) {
    final custom = _customCode;
    final results = _results;

    return AlertDialog(
      title: const Text('Trip currency'),
      content: SizedBox(
        width: 380,
        height: 440,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(24)],
              decoration: const InputDecoration(
                hintText: 'Search, or type any 3-letter code',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            if (custom != null)
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: Text('Use $custom'),
                subtitle: Text('Shown as ${Money.format(1234, custom)}'),
                onTap: () => Navigator.pop(context, custom),
              ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text('No match. Type a 3-letter currency code.'),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final option = results[index];
                        return ListTile(
                          dense: true,
                          selected: option.code == widget.selected,
                          leading: SizedBox(
                            width: 46,
                            child: Text(
                              Money.symbolFor(option.code),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          title: Text(option.name),
                          subtitle: Text(option.code),
                          onTap: () => Navigator.pop(context, option.code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
