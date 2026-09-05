import 'package:flutter/material.dart';

import '../../../service/map_service.dart';
import 'destination_autocomplete_field.dart';

class AddDestinationValue {
  const AddDestinationValue({required this.destination, this.placeId});

  final String destination;

  /// Google placeId of the picked suggestion, when the user chose one.
  /// Null means the destination was typed by hand and has to be resolved
  /// from its text.
  final String? placeId;
}

class AddDestinationDialog extends StatefulWidget {
  const AddDestinationDialog({
    super.key,
    this.initialDestination = '',
    this.editing = false,
  });

  final String initialDestination;
  final bool editing;

  @override
  State<AddDestinationDialog> createState() => _AddDestinationDialogState();
}

class _AddDestinationDialogState extends State<AddDestinationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _destinationController;
  PlaceSuggestion? _selectedSuggestion;

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController(
      text: widget.initialDestination,
    );
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final text = _destinationController.text.trim();
    final suggestion = _selectedSuggestion;
    // Only trust the id while it still describes the text in the field.
    final matchesText =
        suggestion != null &&
        suggestion.placeId.isNotEmpty &&
        suggestion.description.trim() == text;
    Navigator.pop(
      context,
      AddDestinationValue(
        destination: text,
        placeId: matchesText ? suggestion.placeId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editing ? 'Edit destination' : 'Add destination'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: DestinationAutocompleteField(
            controller: _destinationController,
            autofocus: true,
            onChanged: () {},
            onSuggestionSelected: (suggestion) =>
                _selectedSuggestion = suggestion,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a destination.'
                : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.editing ? 'Save changes' : 'Add destination'),
        ),
      ],
    );
  }
}
