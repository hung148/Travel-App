import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../models/planner_result.dart';
import '../../models/trip/trip.dart';
import '../../models/trip/trip_segment.dart';
import '../../service/ai/itinerary_import_service.dart';
import '../../service/trip_clock.dart';
import '../../service/trip_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/manual_planner_dialog.dart';
import '../../widgets/booking_info.dart';
import '../saved_trip/saved_trip_details_page.dart';

class ExistingPlanPage extends StatefulWidget {
  final Trip? trip;
  const ExistingPlanPage({super.key, this.trip});
  @override
  State<ExistingPlanPage> createState() => _ExistingPlanPageState();
}

class _ExistingPlanPageState extends State<ExistingPlanPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _destination = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _zone = TextEditingController();
  final _paste = TextEditingController();
  late final List<TripSegment> _segments = [...?widget.trip?.segments];
  List<PlannerDay> _days = [];
  int _selected = 0;
  bool _busy = false;
  bool _approved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.text = widget.trip?.title ?? '';
    if (_segments.isNotEmpty) { _load(_segments.first); }
    else {
      _destination.text = widget.trip?.destination ?? '';
      _start.text = widget.trip?.startDate == null ? '' : TripClock.dateKey(widget.trip!.startDate!);
      _end.text = widget.trip?.endDate == null ? '' : TripClock.dateKey(widget.trip!.endDate!);
    }
  }
  void _load(TripSegment segment) {
    _destination.text = segment.destination;
    _start.text = TripClock.dateKey(segment.startDate);
    _end.text = TripClock.dateKey(segment.endDate);
    _zone.text = segment.timeZone ?? '';
    _days = segment.days;
  }
  @override
  void dispose() {
    for (final controller in [_title, _destination, _start, _end, _zone, _paste]) { controller.dispose(); }
    super.dispose();
  }
  bool _prepare() {
    if (!_form.currentState!.validate()) return false;
    final start = TripClock.parseDate(_start.text.trim())!;
    final end = TripClock.parseDate(_end.text.trim())!;
    final count = end.difference(start).inDays + 1;
    if (count < 1 || count > 365) { setState(() => _error = 'Use a trip length between 1 and 365 days.'); return false; }
    if (_days.any((day) => day.dayNumber > count && day.places.isNotEmpty)) {
      setState(() => _error = 'Move or remove items outside the new dates before shortening this destination.'); return false;
    }
    _days = List.generate(count, (index) => _days.where((day) => day.dayNumber == index + 1).firstOrNull ?? PlannerDay(dayNumber: index + 1, places: []));
    setState(() => _error = null);
    return true;
  }
  TripSegment _segment() {
    final original = _segments.isEmpty ? null : _segments[_selected];
    return (original ?? TripSegment(id: 'segment-${DateTime.now().microsecondsSinceEpoch}',
      destination: '', startDate: DateTime(2000), endDate: DateTime(2000), allocatedBudget: 0))
      .copyWith(destination: _destination.text.trim(), startDate: TripClock.parseDate(_start.text.trim()),
        endDate: TripClock.parseDate(_end.text.trim()), timeZone: _zone.text.trim(), days: _days);
  }
  Future<void> _edit([List<PlannerDay>? imported]) async {
    if (!_prepare()) return;
    final result = await showDialog<List<PlannerDay>>(context: context, barrierDismissible: false,
      builder: (_) => ManualPlannerDialog(initialDays: imported ?? _days,
        startDate: TripClock.parseDate(_start.text.trim()), timeZone: _zone.text.trim()));
    if (!mounted || result == null) return;
    setState(() { _days = result; _approved = false; });
  }
  Future<void> _import() async {
    if (!_prepare()) return;
    if (_paste.text.trim().isEmpty) { setState(() => _error = 'Paste an itinerary first.'); return; }
    setState(() { _busy = true; _error = null; });
    final service = ItineraryImportService(endpoint: AppConfig.itineraryImportUrl);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final draft = await service.importText(text: _paste.text, start: TripClock.parseDate(_start.text.trim())!,
        dayCount: _days.length, zone: _zone.text.trim(), token: token);
      if (!mounted) return;
      // Append to the existing schedule. Cancel leaves the saved draft intact.
      final merged = List.generate(_days.length, (i) => PlannerDay(dayNumber: i + 1,
        places: [..._days[i].places, ...draft[i].places]));
      await _edit(merged);
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { service.close(); if (mounted) setState(() => _busy = false); }
  }
  Future<void> _save() async {
    if (!_prepare() || !_approved) return;
    final segment = _segment();
    final segments = [..._segments];
    if (segments.isEmpty) { segments.add(segment); } else { segments[_selected] = segment; }
    if (segments.every((segment) => segment.days.every((day) => day.places.isEmpty))) {
      setState(() => _error = 'Add at least one itinerary item.'); return;
    }
    for (final segment in segments) {
      for (final day in segment.days) {
        final expected = TripClock.dateKey(segment.startDate.add(Duration(days: day.dayNumber - 1)));
        if (day.places.any((item) => item.place.booking?.localDate != null && item.place.booking!.localDate != expected)) {
          setState(() => _error = 'An item date does not match its day. Edit it before saving.'); return;
        }
      }
    }
    segments.sort((a, b) => a.startDate.compareTo(b.startDate));
    final start = segments.first.startDate;
    final end = segments.map((s) => s.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
    if (end.difference(start).inDays >= 365) { setState(() => _error = 'The full trip must fit within 365 days.'); return; }
    final uid = context.read<AuthViewModel>().user?.uid;
    if (uid == null) { setState(() => _error = 'Sign in before saving.'); return; }
    final existing = widget.trip;
    final trip = (existing ?? Trip(id: 'trip-${DateTime.now().microsecondsSinceEpoch}', ownerId: uid,
      destination: '', budget: 0, days: 0, status: 'draft')).copyWith(
        title: _title.text.trim().isEmpty ? segment.destination : _title.text.trim(),
        destination: segments.map((s) => s.destination).join(', '), startDate: start, endDate: end,
        days: end.difference(start).inDays + 1, segments: segments);
    setState(() => _busy = true);
    final service = TripService();
    final result = existing == null ? await service.addTrip(trip) : await service.updateTrip(trip);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.success) { setState(() => _error = 'Could not save. Your draft is still here; check your connection and retry.'); return; }
    if (existing != null) { Navigator.pop(context, trip); }
    else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SavedTripDetailsPage(trip: trip, initialTab: 4))); }
  }

  Widget _field(TextEditingController controller, String label, {String? Function(String)? validate, int maxLength = 200}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: TextFormField(controller: controller,
      maxLength: maxLength, decoration: InputDecoration(labelText: label, counterText: ''),
      onChanged: (_) => setState(() => _approved = false),
      validator: (value) => validate?.call((value ?? '').trim())));

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.trip == null ? 'Add my existing plan' : 'Edit trip details')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
      child: AbsorbPointer(absorbing: _busy, child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Keep flights, pickups, bookings, and personal activities together. No generated plan is required.'),
        const SizedBox(height: 20),
        _field(_title, 'Trip title'),
        if (_segments.length > 1) DropdownButtonFormField<int>(initialValue: _selected,
          decoration: const InputDecoration(labelText: 'Destination to edit'),
          items: List.generate(_segments.length, (i) => DropdownMenuItem(value: i, child: Text(_segments[i].destination))),
          onChanged: (index) { if (index == null || !_prepare()) return; setState(() { _segments[_selected] = _segment(); _selected = index; _load(_segments[index]); _approved = false; }); }),
        _field(_destination, 'Destination', validate: (v) => v.isEmpty ? 'Enter a destination' : null),
        _field(_start, 'Start date (YYYY-MM-DD)', validate: (v) => TripClock.parseDate(v) == null ? 'Enter a valid date' : null),
        _field(_end, 'End date (YYYY-MM-DD)', validate: (v) => TripClock.parseDate(v) == null ? 'Enter a valid date' : null),
        _field(_zone, 'Destination time zone (e.g. Asia/Ho_Chi_Minh)', validate: (v) => !TripClock.validZone(v) ? 'Enter an IANA time zone' : null),
        OutlinedButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.edit_calendar), label: const Text('Add or edit itinerary items')),
        const SizedBox(height: 24),
        TextFormField(controller: _paste, minLines: 4, maxLines: 8, maxLength: 20000,
          decoration: const InputDecoration(labelText: 'Paste your itinerary (optional)', hintText: 'AI creates a draft. Review dates and details before saving.')),
        OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.auto_awesome), label: const Text('Import and review draft')),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        for (final day in _days) ExpansionTile(title: Text('Day ${day.dayNumber} · ${day.places.length} items'), children: [
          for (final item in day.places) ListTile(title: Text(item.place.name), subtitle: BookingInfo(place: item.place)),
        ]),
        CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('I reviewed the dates, times, and booking details'),
          value: _approved, onChanged: (value) => setState(() => _approved = value ?? false)),
        FilledButton(onPressed: _approved ? _save : null, child: const Text('Save trip')),
      ]))))));
}
