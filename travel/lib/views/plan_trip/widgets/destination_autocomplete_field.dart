import 'dart:async';

import 'package:flutter/material.dart';

import '../../../service/osm_map_service.dart';
import '../../../widgets/osm_credit.dart';
import '../../../service/map_service.dart';

class DestinationAutocompleteField extends StatefulWidget {
  const DestinationAutocompleteField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
    this.validator,
    this.mapService,
    this.onSuggestionSelected,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool autofocus;
  final FormFieldValidator<String>? validator;

  /// Fires with the suggestion the user picked, or null when the text is
  /// edited by hand. The placeId is what lets planning resolve the exact
  /// city instead of guessing from the text.
  final ValueChanged<PlaceSuggestion?>? onSuggestionSelected;

  /// May be injected by tests. The configured Google service is used by
  /// default, while manual entry remains available without an API key.
  final MapService? mapService;

  @override
  State<DestinationAutocompleteField> createState() =>
      _DestinationAutocompleteFieldState();
}

class _DestinationAutocompleteFieldState
    extends State<DestinationAutocompleteField> {
  final _menuController = MenuController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _loading = false;
  int _requestNumber = 0;
  String? _searchMessage;
  late final MapService _defaultService = OsmMapService();

  MapService? get _mapService => widget.mapService ?? _defaultService;

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _queryChanged(String value) {
    // Typing invalidates any previously picked place: the id would no longer
    // describe the text in the field.
    widget.onSuggestionSelected?.call(null);
    widget.onChanged();
    _debounce?.cancel();
    _search(value);
  }

  void _search(String value) {
    _debounce?.cancel();
    _focusNode.requestFocus();
    final currentRequest = ++_requestNumber;
    final query = value.trim();
    if (query.length < 2 || _mapService == null) {
      _requestNumber++;
      setState(() {
        _loading = false;
        _suggestions = const [];
      });
      if (_menuController.isOpen) _menuController.close();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (mounted) setState(() => _loading = true);
      try {
        // Trip segments need a broad planning area, not an individual hotel,
        // attraction, address, or transit stop.
        final results = await _mapService!.getPlaceSuggestions(
          query,
          tripDestinationsOnly: true,
        );
        if (!mounted || currentRequest != _requestNumber) return;
        setState(() {
          _suggestions = results;
          _loading = false;
          _searchMessage = results.isEmpty
              ? 'No city found. Try the full local or English name, or choose an area on the map.'
              : null;
        });
        if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
          _menuController.open();
        } else if (_menuController.isOpen) {
          _menuController.close();
        }
      } catch (_) {
        if (!mounted || currentRequest != _requestNumber) return;
        setState(() {
          _loading = false;
          _suggestions = const [];
          _searchMessage = 'Search is unavailable. Try again shortly.';
        });
        if (_menuController.isOpen) _menuController.close();
      }
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    _debounce?.cancel();
    _requestNumber++;
    widget.controller.text = suggestion.description;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    setState(() => _suggestions = const []);
    _menuController.close();
    _focusNode.unfocus();
    widget.onSuggestionSelected?.call(suggestion);
    widget.onChanged();
  }

  Future<void> _searchGoogle() async {
    final service = _mapService;
    if (service is! OsmMapService || _loading) return;
    final number = ++_requestNumber;
    setState(() => _loading = true);
    try {
      final results = await service.searchGoogle(widget.controller.text);
      if (!mounted || number != _requestNumber) return;
      setState(() {
        _suggestions = results;
        _loading = false;
        _searchMessage = results.isEmpty
            ? 'No result. Choose an area on the map.'
            : null;
      });
      if (results.isNotEmpty) _menuController.open();
    } catch (_) {
      if (!mounted || number != _requestNumber) return;
      setState(() {
        _loading = false;
        _searchMessage =
            'Google search is unavailable or its daily limit was reached.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        controller: _menuController,
        alignmentOffset: const Offset(0, 6),
        menuChildren: [
          for (final suggestion in _suggestions)
            SizedBox(
              width: constraints.maxWidth,
              child: MenuItemButton(
                leadingIcon: const Icon(Icons.location_on_outlined),
                onPressed: () => _selectSuggestion(suggestion),
                child: Text(
                  suggestion.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (_suggestions.isNotEmpty)
            SizedBox(
              width: constraints.maxWidth,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      _suggestions.any((p) => p.placeId.startsWith('google:'))
                      ? const Text('Google Maps')
                      : const OsmCredit(),
                ),
              ),
            ),
        ],
        builder: (context, controller, child) => TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onChanged: _queryChanged,
          onFieldSubmitted: _search,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: 'Destination',
            hintText: 'Tokyo, Japan',
            helperText: _searchMessage ?? 'Start typing a city name.',
            helperMaxLines: 3,
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _searchMessage != null &&
                      _mapService is OsmMapService &&
                      (_mapService as OsmMapService).googleFallbackAvailable
                ? TextButton(
                    onPressed: _searchGoogle,
                    child: const Text('Search Google'),
                  )
                : IconButton(
                    tooltip: 'Search destination',
                    onPressed: () => _search(widget.controller.text),
                    icon: const Icon(Icons.search),
                  ),
          ),
        ),
      ),
    );
  }
}
