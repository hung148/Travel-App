import 'package:flutter/material.dart';
import '../models/planner_result.dart';
import '../models/score_place.dart';
import '../service/trip_clock.dart';
import 'booking_editor.dart';

class ManualPlannerDialog extends StatefulWidget {
  final List<PlannerDay> initialDays;
  final List<ScoredPlace> rankedPlaces;
  final DateTime? startDate;
  final String? timeZone;

  const ManualPlannerDialog({super.key, required this.initialDays, this.rankedPlaces = const [], this.startDate, this.timeZone});

  @override
  State<ManualPlannerDialog> createState() => ManualPlannerDialogState();
}

class ManualPlannerDialogState extends State<ManualPlannerDialog> {
  final searchController = TextEditingController();
  late final List<PlannerDay> days = widget.initialDays
      .map(
        (day) => PlannerDay(
          dayNumber: day.dayNumber,
          places: List<ScoredPlace>.of(day.places),
        ),
      )
      .toList();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Set<String> get _usedPlaceIds =>
      days.expand((day) => day.places).map((item) => item.place.id).toSet();

  List<ScoredPlace> get _availablePlaces {
    final query = searchController.text.trim().toLowerCase();
    final used = _usedPlaceIds;
    return widget.rankedPlaces.where((item) {
      if (used.contains(item.place.id)) return false;
      if (query.isEmpty) return true;
      return item.place.name.toLowerCase().contains(query) ||
          item.place.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _editItem(int dayIndex, [int? stopIndex]) async {
    final date = widget.startDate == null ? null : TripClock.dateKey(widget.startDate!.add(Duration(days: dayIndex)));
    final item = await showDialog<ScoredPlace>(context: context,
      builder: (_) => BookingEditor(initial: stopIndex == null ? null : days[dayIndex].places[stopIndex], date: date, timeZone: widget.timeZone));
    if (!mounted || item == null) return;
    final itemDate = item.place.booking?.localDate;
    var target = dayIndex;
    if (itemDate != null && widget.startDate != null) {
      final parsed = TripClock.parseDate(itemDate)!;
      target = DateTime.utc(parsed.year, parsed.month, parsed.day).difference(DateTime.utc(widget.startDate!.year, widget.startDate!.month, widget.startDate!.day)).inDays;
      if (target < 0 || target >= days.length) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The item date must be within this destination’s dates.')));
        return;
      }
    }
    setState(() {
      if (stopIndex != null) days[dayIndex].places.removeAt(stopIndex);
      if (target == dayIndex && stopIndex != null) { days[target].places.insert(stopIndex, item); }
      else { days[target].places.add(item); }
    });
  }

  void _addPlace(ScoredPlace place, int dayIndex) {
    setState(() => days[dayIndex].places.add(place));
  }

  void _removePlace(int dayIndex, int stopIndex) {
    setState(() => days[dayIndex].places.removeAt(stopIndex));
  }

  void _movePlace(int dayIndex, int stopIndex, int offset) {
    final nextIndex = stopIndex + offset;
    if (nextIndex < 0 || nextIndex >= days[dayIndex].places.length) return;
    setState(() {
      final item = days[dayIndex].places.removeAt(stopIndex);
      days[dayIndex].places.insert(nextIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_calendar_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review and edit itinerary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Add places to any day, then reorder them into the sequence you want.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final available = _AvailableManualPlaces(
                      searchController: searchController,
                      places: _availablePlaces,
                      dayCount: days.length,
                      onSearchChanged: (_) => setState(() {}),
                      onAdd: _addPlace,
                    );
                    final itinerary = _ManualDayEditor(
                      days: days,
                      onRemove: _removePlace,
                      onMove: _movePlace,
                      onEdit: _editItem,
                      onAddCustom: (day) => _editItem(day),
                    );
                    if (compact) {
                      return Column(
                        children: [
                          Expanded(child: available),
                          const Divider(height: 24),
                          Expanded(child: itinerary),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: available),
                        const VerticalDivider(width: 28),
                        Expanded(child: itinerary),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, days),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use manual plan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableManualPlaces extends StatelessWidget {
  final TextEditingController searchController;
  final List<ScoredPlace> places;
  final int dayCount;
  final ValueChanged<String> onSearchChanged;
  final void Function(ScoredPlace place, int dayIndex) onAdd;

  const _AvailableManualPlaces({
    required this.searchController,
    required this.places,
    required this.dayCount,
    required this.onSearchChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available places (${places.length})',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search name or category',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: places.isEmpty
              ? const Center(child: Text('No unused places match this search.'))
              : ListView.separated(
                  itemCount: places.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = places[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item.place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item.place.category} • '
                          '${item.place.estimatedVisitMinutes} min',
                        ),
                        trailing: PopupMenuButton<int>(
                          tooltip: 'Add to day',
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onSelected: (dayIndex) => onAdd(item, dayIndex),
                          itemBuilder: (context) => List.generate(
                            dayCount,
                            (dayIndex) => PopupMenuItem(
                              value: dayIndex,
                              child: Text('Add to Day ${dayIndex + 1}'),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ManualDayEditor extends StatelessWidget {
  final List<PlannerDay> days;
  final void Function(int dayIndex, int stopIndex) onRemove;
  final void Function(int dayIndex, int stopIndex) onEdit;
  final ValueChanged<int> onAddCustom;
  final void Function(int dayIndex, int stopIndex, int offset) onMove;

  const _ManualDayEditor({
    required this.days,
    required this.onRemove,
    required this.onEdit,
    required this.onAddCustom,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your days', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: days.length,
            itemBuilder: (context, dayIndex) {
              final day = days[dayIndex];
              return Card(
                child: ExpansionTile(
                  initiallyExpanded: dayIndex < 2,
                  leading: IconButton(tooltip: 'Add custom item', icon: const Icon(Icons.add), onPressed: () => onAddCustom(dayIndex)),
                  title: Text(
                    'Day ${day.dayNumber} • ${day.places.length} stops',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  children: day.places.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('No places added yet.'),
                            ),
                          ),
                        ]
                      : List.generate(day.places.length, (stopIndex) {
                          final item = day.places[stopIndex];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              child: Text('${stopIndex + 1}'),
                            ),
                            onTap: () => onEdit(dayIndex, stopIndex),
                            title: Text(item.place.name),
                            subtitle: Text('${item.place.category} • Tap to edit booking details'),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Item actions',
                              onSelected: (action) {
                                if (action == 'earlier') onMove(dayIndex, stopIndex, -1);
                                if (action == 'later') onMove(dayIndex, stopIndex, 1);
                                if (action == 'remove') onRemove(dayIndex, stopIndex);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'earlier', enabled: stopIndex > 0, child: const Text('Move earlier')),
                                PopupMenuItem(value: 'later', enabled: stopIndex < day.places.length - 1, child: const Text('Move later')),
                                const PopupMenuItem(value: 'remove', child: Text('Remove')),
                              ],
                            ),
                          );
                        }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

