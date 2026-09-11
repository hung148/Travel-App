import 'package:flutter/material.dart';
import '../models/booking_details.dart';
import '../models/cost_estimate.dart';
import '../models/score_place.dart';
import '../models/travel_place.dart';
import '../service/trip_clock.dart';

class BookingEditor extends StatefulWidget {
  final ScoredPlace? initial;
  final String? date;
  final String? timeZone;
  const BookingEditor({super.key, this.initial, this.date, this.timeZone});
  @override
  State<BookingEditor> createState() => _BookingEditorState();
}

class _BookingEditorState extends State<BookingEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  late bool confirmed = widget.initial?.place.booking?.confirmed ?? false;
  TextEditingController field(String name) => _fields[name]!;
  @override
  void initState() {
    super.initState();
    final place = widget.initial?.place;
    final booking = place?.booking;
    final minutes = booking?.startMinutes;
    final values = {
      'Name': place?.name ?? '', 'Category': place?.category ?? 'personal',
      'Date (YYYY-MM-DD)': booking?.localDate ?? widget.date ?? '',
      'Time (HH:mm, optional)': minutes == null ? '' : '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
      'Time zone (IANA)': booking?.timeZone ?? widget.timeZone ?? '',
      'Address or meeting point': booking?.address ?? '',
      'Booking reference': booking?.reference ?? '', 'Provider': booking?.provider ?? '',
      'Contact details': booking?.contact ?? '', 'Notes': booking?.notes ?? '',
      'Latitude (optional)': place?.hasLocation == true ? '${place!.latitude}' : '',
      'Longitude (optional)': place?.hasLocation == true ? '${place!.longitude}' : '',
    };
    for (final entry in values.entries) { _fields[entry.key] = TextEditingController(text: entry.value); }
  }
  @override
  void dispose() { for (final field in _fields.values) { field.dispose(); } super.dispose(); }

  String? validate(String key, String text) {
    if (key == 'Name' && text.isEmpty) return 'Enter a name';
    if (key == 'Date (YYYY-MM-DD)' && text.isNotEmpty && TripClock.parseDate(text) == null) return 'Use a valid YYYY-MM-DD date';
    if (key == 'Time (HH:mm, optional)' && text.isNotEmpty && !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) return 'Use 24-hour HH:mm';
    if (key == 'Time zone (IANA)' && text.isNotEmpty && !TripClock.validZone(text)) return 'Use an IANA zone, e.g. Asia/Ho_Chi_Minh';
    if (key.startsWith('Latitude') || key.startsWith('Longitude')) {
      final other = key.startsWith('Latitude') ? 'Longitude (optional)' : 'Latitude (optional)';
      if (text.isEmpty && field(other).text.trim().isNotEmpty) return 'Enter both coordinates';
      if (text.isNotEmpty) {
        final value = double.tryParse(text);
        final limit = key.startsWith('Latitude') ? 90 : 180;
        if (value == null || !value.isFinite || value.abs() > limit) return 'Enter a coordinate between -$limit and $limit';
      }
    }
    return null;
  }
  void save() {
    if (!_form.currentState!.validate()) return;
    String value(String key) => field(key).text.trim();
    String? optional(String key) => value(key).isEmpty ? null : value(key);
    final time = optional('Time (HH:mm, optional)')?.split(':');
    final original = widget.initial;
    final map = original?.place.toMap() ?? TravelPlace(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}', name: '', category: 'personal',
      tags: const [], rating: 0, reviewCount: 0,
      cost: const CostEstimate(low: 0, high: 0, currencyCode: 'USD', basis: CostBasis.perGroup, source: CostSource.unknown),
      latitude: 0, longitude: 0, estimatedVisitMinutes: 0, isCustom: true, hasLocation: false,
    ).toMap();
    map.addAll({
      'name': value('Name'), 'category': value('Category'),
      'latitude': double.tryParse(value('Latitude (optional)')) ?? 0,
      'longitude': double.tryParse(value('Longitude (optional)')) ?? 0,
      'hasLocation': value('Latitude (optional)').isNotEmpty,
      'booking': BookingDetails(localDate: optional('Date (YYYY-MM-DD)'),
        startMinutes: time == null ? null : int.parse(time[0]) * 60 + int.parse(time[1]),
        timeZone: optional('Time zone (IANA)'), address: value('Address or meeting point'),
        reference: value('Booking reference'), provider: value('Provider'), contact: value('Contact details'),
        notes: value('Notes'), confirmed: confirmed).toMap(),
    });
    Navigator.pop(context, ScoredPlace.fromMap({...?original?.toMap(), 'place': map}));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add custom item' : 'Edit item and booking'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Leave unknown details blank. Times use the destination time zone.'),
        for (final entry in _fields.entries) Padding(padding: const EdgeInsets.only(top: 12),
          child: TextFormField(controller: entry.value, maxLength: entry.key == 'Notes' ? 4000 : 500,
            minLines: entry.key == 'Notes' ? 2 : 1, maxLines: entry.key == 'Notes' ? 4 : 1,
            decoration: InputDecoration(labelText: entry.key, counterText: ''),
            validator: (text) => validate(entry.key, (text ?? '').trim()))),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Confirmed booking'),
          subtitle: const Text('AI must preserve this item and its fixed time.'),
          value: confirmed, onChanged: (value) => setState(() => confirmed = value)),
      ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: save, child: const Text('Use item'))],
  );
}
