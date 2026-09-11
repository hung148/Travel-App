import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/trip/trip.dart';
import '../../models/planner_result.dart';
import '../../service/trip_clock.dart';
import '../../service/planner/daily_time_schedule_service.dart';
import '../../widgets/booking_info.dart';

class TodayView extends StatefulWidget {
  final Trip trip;
  final DateTime Function()? now;
  const TodayView({super.key, required this.trip, this.now});
  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  int _segment = 0;
  int? _day;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    final segments = widget.trip.segments;
    for (var i = 0; i < segments.length; i++) {
      final now = TripClock.localNow(segments[i].timeZone, now: widget.now?.call());
      if (now == null) continue;
      final key = TripClock.dateKey(now);
      if (key.compareTo(TripClock.dateKey(segments[i].startDate)) >= 0 &&
          key.compareTo(TripClock.dateKey(segments[i].endDate)) <= 0) { _segment = i; break; }
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.trip.segments.isEmpty) return const Text('This older trip has no daily schedule. Open Edit plan to add its details.');
    final segment = widget.trip.segments[_segment];
    final now = TripClock.localNow(segment.timeZone, now: widget.now?.call());
    final localDay = now == null ? null : DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(segment.startDate.year, segment.startDate.month, segment.startDate.day)).inDays + 1;
    final count = segment.numberOfDays.clamp(1, 365);
    final dayNumber = (_day ?? localDay ?? 1).clamp(1, count);
    final day = segment.days.where((day) => day.dayNumber == dayNumber).firstOrNull ?? PlannerDay(dayNumber: dayNumber, places: const []);
    final scheduled = const DailyTimeScheduleService().schedule(day.places, startTimeOverrides: segment.startTimeOverrides);
    int? minutes(int i) => day.places[i].place.isCustom ? day.places[i].place.booking?.startMinutes : scheduled[i].startMinutes;
    final indexes = List.generate(day.places.length, (i) => i)..sort((a, b) {
      final compare = (minutes(a) ?? 100000).compareTo(minutes(b) ?? 100000);
      return compare == 0 ? a.compareTo(b) : compare;
    });
    final isToday = localDay == dayNumber;
    final next = now == null || !isToday ? null : indexes.where((i) => minutes(i) != null && minutes(i)! >= now.hour * 60 + now.minute).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Today', style: Theme.of(context).textTheme.headlineSmall),
      if (now == null) const Text('Set the destination time zone in Edit plan to show its local today. Browse days below.'),
      if (now != null) Text('${TripClock.dateKey(now)} · ${segment.timeZone}'),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(initialValue: _segment,
        decoration: const InputDecoration(labelText: 'Destination'),
        items: List.generate(widget.trip.segments.length, (i) => DropdownMenuItem(value: i, child: Text(widget.trip.segments[i].destination))),
        onChanged: (value) => setState(() { _segment = value ?? 0; _day = null; })),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(key: ValueKey('$_segment-$dayNumber'), initialValue: dayNumber,
        decoration: const InputDecoration(labelText: 'Day'),
        items: List.generate(count, (i) => DropdownMenuItem(value: i + 1,
          child: Text('Day ${i + 1} · ${TripClock.dateKey(segment.startDate.add(Duration(days: i)))}'))),
        onChanged: (value) => setState(() => _day = value)),
      const SizedBox(height: 16),
      if (!isToday) const Text('Browsing a trip day'),
      if (next != null) Text('Next: ${day.places[next].place.name}', style: Theme.of(context).textTheme.titleLarge),
      if (isToday && next == null) const Text('No more timed activities today. Check any items with an unknown time below.'),
      if (indexes.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No items scheduled for this day.')),
      for (final i in indexes) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(minutes(i) == null ? 'Time unknown' : '${scheduled[i].formattedStartTime}${day.places[i].place.booking?.startMinutes == null ? ' (suggested)' : ''}'),
          Text(day.places[i].place.name, style: Theme.of(context).textTheme.titleMedium),
          BookingInfo(place: day.places[i].place),
        ]))),
    ]);
  }
}
