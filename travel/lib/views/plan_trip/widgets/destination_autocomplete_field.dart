import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../service/map_service.dart';

class DestinationAutocompleteField extends StatefulWidget {
  const DestinationAutocompleteField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
    this.validator,
    this.mapService,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool autofocus;
  final FormFieldValidator<String>? validator;

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

  MapService? get _mapService =>
      widget.mapService ??
      (AppConfig.hasGoogleMapsApiKey
          ? MapService(apiKey: AppConfig.googleMapsApiKey)
          : null);

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _queryChanged(String value) {
    widget.onChanged();
    _debounce?.cancel();
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
      final currentRequest = ++_requestNumber;
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
    widget.onChanged();
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
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Powered by Google',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            ),
        ],
        builder: (context, controller, child) => TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onChanged: _queryChanged,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: 'Destination',
            hintText: 'Tokyo, Japan',
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
                : null,
          ),
        ),
      ),
    );
  }
}
