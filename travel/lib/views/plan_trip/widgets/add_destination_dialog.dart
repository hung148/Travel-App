import 'package:flutter/material.dart';

import 'destination_autocomplete_field.dart';
import '../models/destination_date_availability.dart';
import '../models/travel_leg_draft.dart';

class AddDestinationValue {
  const AddDestinationValue({
    required this.destination,
    required this.dates,
    required this.budget,
    this.incomingTravelEstimate,
  });

  final String destination;
  final DateTimeRange dates;
  final double budget;
  final TravelEstimate? incomingTravelEstimate;
}

class AddDestinationDialog extends StatefulWidget {
  const AddDestinationDialog({
    super.key,
    this.unavailableDateRanges = const [],
    this.previousDestinationEnd,
    this.estimateIncomingTravel,
  });

  final List<DateTimeRange> unavailableDateRanges;
  final DateTime? previousDestinationEnd;
  final Future<TravelEstimate?> Function(String destination)?
  estimateIncomingTravel;

  @override
  State<AddDestinationDialog> createState() => _AddDestinationDialogState();
}

class _AddDestinationDialogState extends State<AddDestinationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTimeRange? _dates;
  TravelEstimate? _incomingEstimate;
  bool _estimatingTravel = false;

  @override
  void dispose() {
    _destinationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  String get _dateLabel {
    final dates = _dates;
    if (dates == null) return 'Choose dates';
    String format(DateTime value) =>
        '${value.month}/${value.day}/${value.year}';
    return '${format(dates.start)} - ${format(dates.end)}';
  }

  Future<void> _pickDates() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      _formKey.currentState!.validate();
      return;
    }
    final estimator = widget.estimateIncomingTravel;
    if (estimator != null) {
      setState(() => _estimatingTravel = true);
      _incomingEstimate = await estimator(destination);
      if (!mounted) return;
      setState(() => _estimatingTravel = false);
    }
    final now = DateTime.now();
    final unavailable = List<DateTimeRange>.of(widget.unavailableDateRanges);
    final transit = widget.previousDestinationEnd == null
        ? null
        : transitDateRange(
            widget.previousDestinationEnd!,
            _incomingEstimate?.transitDays ?? 0,
          );
    if (transit != null) unavailable.add(transit);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDateRange: _dates,
      helpText: 'Select available destination dates',
      selectableDayPredicate: (day, selectedStart, selectedEnd) =>
          !isDateUnavailable(day, unavailable),
    );
    if (picked != null && mounted) setState(() => _dates = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_dates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose start and end dates.')),
      );
      return;
    }
    final unavailable = List<DateTimeRange>.of(widget.unavailableDateRanges);
    final transit = widget.previousDestinationEnd == null
        ? null
        : transitDateRange(
            widget.previousDestinationEnd!,
            _incomingEstimate?.transitDays ?? 0,
          );
    if (transit != null) unavailable.add(transit);
    if (dateRangeOverlaps(_dates!, unavailable)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('These dates overlap another destination.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      AddDestinationValue(
        destination: _destinationController.text.trim(),
        dates: _dates!,
        budget: double.parse(_budgetController.text.trim()),
        incomingTravelEstimate: _incomingEstimate,
      ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DestinationAutocompleteField(
                controller: _destinationController,
                autofocus: true,
                onChanged: () {},
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a destination.'
                    : null,
              ),
              const SizedBox(height: 14),
              if (_incomingEstimate != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Estimated ${_incomingEstimate!.mode.name}: '
                    '${_incomingEstimate!.durationHours.toStringAsFixed(1)} hours '
                    '(${_incomingEstimate!.distanceKm.toStringAsFixed(0)} km)',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _estimatingTravel ? null : _pickDates,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _estimatingTravel
                          ? 'Estimating travel time...'
                          : _dateLabel,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Budget',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 0
                      ? 'Enter a non-negative budget.'
                      : null;
                },
              ),
            ],
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
