import 'package:flutter/material.dart';

import 'destination_autocomplete_field.dart';

class AddDestinationValue {
  const AddDestinationValue({required this.destination});

  final String destination;
}

class AddDestinationDialog extends StatefulWidget {
  const AddDestinationDialog({super.key});

  @override
  State<AddDestinationDialog> createState() => _AddDestinationDialogState();
}

class _AddDestinationDialogState extends State<AddDestinationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();

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
      title: const Text('Add destination'),
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
        FilledButton(onPressed: _submit, child: const Text('Add destination')),
      ],
    );
  }
}
