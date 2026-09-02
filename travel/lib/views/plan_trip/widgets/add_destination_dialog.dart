import 'package:flutter/material.dart';

import 'destination_autocomplete_field.dart';

class AddDestinationValue {
  const AddDestinationValue({required this.destination});

  final String destination;
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
    Navigator.pop(
      context,
      AddDestinationValue(destination: _destinationController.text.trim()),
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
