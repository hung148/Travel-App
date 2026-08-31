import 'package:flutter/material.dart';

import '../../models/planner_result.dart';
import '../../models/preference/preferences.dart';
import '../../models/trip/trip.dart';
import '../../service/planner/mock_places.dart';
import '../../service/planner/place_scoring_service.dart';
import '../../service/planner/travel_planner_service.dart';
import 'ai_chat_widget.dart';

class PlanTripPage extends StatefulWidget {
  const PlanTripPage({super.key});

  @override
  State<PlanTripPage> createState() => _PlanTripPageState();
}

class _PlanTripPageState extends State<PlanTripPage> {
  final destinationController = TextEditingController(text: 'Tokyo, Japan');
  final budgetController = TextEditingController(text: '2000');

  final TravelPlannerService _planner = TravelPlannerService(
    placeScoringService: PlaceScoringService(),
  );

  DateTimeRange? dates;
  int travelers = 2;
  bool planGenerated = false;
  bool isGenerating = false;
  String selectedPlan = 'Balanced';
  PlannerResult? plannerResult;

  @override
  void dispose() {
    destinationController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDateRange: dates,
    );
    if (selected != null && mounted) {
      setState(() => dates = selected);
    }
  }

  String _dateLabel() {
    if (dates == null) return 'Choose travel dates';
    String format(DateTime date) => '${date.month}/${date.day}/${date.year}';
    return '${format(dates!.start)} – ${format(dates!.end)}';
  }

  String _activityLevelForPlan(String plan) {
    switch (plan) {
      case 'Relaxed':
        return 'Relaxed';
      case 'Explorer':
        return 'Very Active';
      default:
        return 'Moderate';
    }
  }

  Preference _testPreference() {
    return Preference(
      id: 'ui_test_preference',
      ownerId: 'ui_test_user',
      experienceType: const ['Food', 'History', 'Culture'],
      activityLevel: _activityLevelForPlan(selectedPlan),
      spendingStyle: 'Normal',
      interests: const ['Local food', 'Museums', 'Photography', 'Attractions'],
    );
  }

  void _generatePlan() {
    final destination = destinationController.text.trim();
    final budget = double.tryParse(budgetController.text.trim());

    if (destination.isEmpty || budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a destination and valid budget first.'),
        ),
      );
      return;
    }

    setState(() => isGenerating = true);

    try {
      final dayCount = dates == null
          ? 3
          : dates!.end.difference(dates!.start).inDays + 1;

      final trip = Trip(
        id: 'ui_test_trip',
        ownerId: 'ui_test_user',
        destination: destination,
        budget: budget,
        days: dayCount,
        status: 'draft',
        startDate: dates?.start,
        endDate: dates?.end,
      );

      final result = _planner.generatePlan(
        trip: trip,
        preference: _testPreference(),
        candidatePlaces: mockTokyoPlaces,
        centerLatitude: 35.6762,
        centerLongitude: 139.6503,
      );

      if (!mounted) return;

      setState(() {
        plannerResult = result;
        planGenerated = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate plan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isGenerating = false);
      }
    }
  }

  void _selectPlan(String value) {
    setState(() => selectedPlan = value);

    if (planGenerated) {
      _generatePlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          children: [
            Icon(Icons.travel_explore),
            SizedBox(width: 10),
            Text('Plan a trip'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draft saved locally for this UI demo.'),
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save draft'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1000;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Build your next trip',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choose the basics, generate a plan, then negotiate changes with the AI planner.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.62),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (desktop)
                          FilledButton.icon(
                            onPressed: isGenerating ? null : _generatePlan,
                            icon: isGenerating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              isGenerating
                                  ? 'Generating...'
                                  : planGenerated
                                      ? 'Regenerate plan'
                                      : 'Generate plan',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _TripSetupCard(
                      destinationController: destinationController,
                      budgetController: budgetController,
                      dateLabel: _dateLabel(),
                      travelers: travelers,
                      onPickDates: _pickDates,
                      onTravelersChanged: (value) =>
                          setState(() => travelers = value),
                    ),
                    if (!desktop) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isGenerating ? null : _generatePlan,
                          icon: isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            isGenerating
                                ? 'Generating...'
                                : planGenerated
                                    ? 'Regenerate plan'
                                    : 'Generate plan',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(flex: 3, child: _MapPlaceholder()),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 430,
                              child: AiChatWidget(
                                onPlanChanged: () {
                                  if (!planGenerated) {
                                    _generatePlan();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      const _MapPlaceholder(),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 430,
                        child: AiChatWidget(
                          onPlanChanged: () {
                            if (!planGenerated) {
                              _generatePlan();
                            }
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _PlanOptions(
                      selectedPlan: selectedPlan,
                      enabled: planGenerated,
                      onSelected: _selectPlan,
                    ),
                    const SizedBox(height: 20),
                    _PlanPreview(
                      generated: planGenerated,
                      selectedPlan: selectedPlan,
                      destination: destinationController.text.trim().isEmpty
                          ? 'your destination'
                          : destinationController.text.trim(),
                      result: plannerResult,
                      onGenerate: _generatePlan,
                      onReview: () => Navigator.pushNamed(context, '/summary'),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripSetupCard extends StatelessWidget {
  final TextEditingController destinationController;
  final TextEditingController budgetController;
  final String dateLabel;
  final int travelers;
  final VoidCallback onPickDates;
  final ValueChanged<int> onTravelersChanged;

  const _TripSetupCard({
    required this.destinationController,
    required this.budgetController,
    required this.dateLabel,
    required this.travelers,
    required this.onPickDates,
    required this.onTravelersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final fields = [
            _LabeledField(
              label: 'Destination',
              child: TextField(
                controller: destinationController,
                decoration: const InputDecoration(
                  hintText: 'Tokyo, Japan',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ),
            _LabeledField(
              label: 'Travel dates',
              child: OutlinedButton.icon(
                onPressed: onPickDates,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(dateLabel),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            _LabeledField(
              label: 'Total budget',
              child: TextField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '2,500',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
            ),
            _LabeledField(
              label: 'Travelers',
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: travelers > 1
                          ? () => onTravelersChanged(travelers - 1)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '$travelers',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onTravelersChanged(travelers + 1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ];

          if (!wide) {
            return Column(
              children: fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: field,
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                Expanded(child: fields[i]),
                if (i != fields.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 430,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.06),
                  child: CustomPaint(painter: _MapGridPainter()),
                ),
              ),
              const Positioned(
                left: 110,
                top: 135,
                child: _MapPin(number: '1'),
              ),
              const Positioned(
                left: 245,
                top: 225,
                child: _MapPin(number: '2'),
              ),
              const Positioned(
                right: 145,
                top: 115,
                child: _MapPin(number: '3'),
              ),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 52),
                    SizedBox(height: 12),
                    Text(
                      'Google Map Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Real Google Maps data will replace this placeholder'),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Chip(
                  avatar: const Icon(Icons.location_searching, size: 18),
                  label: const Text('Destination map'),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String number;
  const _MapPin({required this.number});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      child: Text(number, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _PlanOptions extends StatelessWidget {
  final String selectedPlan;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const _PlanOptions({
    required this.selectedPlan,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final plans = [
      (
        'Relaxed',
        '3 stops/day',
        'Fewer stops • more free time',
        Icons.spa_outlined,
      ),
      (
        'Balanced',
        '4 stops/day',
        'Best mix of places and rest',
        Icons.balance_outlined,
      ),
      (
        'Explorer',
        '6 stops/day',
        'More activities • fuller days',
        Icons.explore_outlined,
      ),
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded),
              const SizedBox(width: 10),
              const Text(
                'Choose a plan style',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  enabled
                      ? 'Changes regenerate the algorithm'
                      : 'Generate a plan first',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: plans.map((plan) {
                  final selected = selectedPlan == plan.$1;
                  return SizedBox(
                    width: cardWidth,
                    child: InkWell(
                      onTap: enabled ? () => onSelected(plan.$1) : null,
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: selected && enabled
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected && enabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.45),
                            width: selected && enabled ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              plan.$4,
                              color: enabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.$1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    plan.$3,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              plan.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlanPreview extends StatelessWidget {
  final bool generated;
  final String selectedPlan;
  final String destination;
  final PlannerResult? result;
  final VoidCallback onGenerate;
  final VoidCallback onReview;

  const _PlanPreview({
    required this.generated,
    required this.selectedPlan,
    required this.destination,
    required this.result,
    required this.onGenerate,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_timeline_outlined),
              const SizedBox(width: 10),
              const Text(
                'Plan preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  generated ? '$selectedPlan plan' : 'No plan generated yet',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!generated || result == null) ...[
            Text(
              'Generate a plan to preview a day-by-day itinerary for $destination.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate algorithm plan'),
            ),
          ] else ...[
            _RankingSummary(result: result!),
            const Divider(height: 32),
            if (result!.days.every((day) => day.places.isEmpty))
              const Text(
                'No places fit the current activity budget. Try increasing the budget.',
              )
            else
              for (int i = 0; i < result!.days.length; i++) ...[
                _GeneratedDayPreview(day: result!.days[i]),
                if (i != result!.days.length - 1)
                  const Divider(height: 32),
              ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Review final plan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingSummary extends StatelessWidget {
  final PlannerResult result;

  const _RankingSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final top = result.rankedPlaces.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top ranked places',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top
              .map(
                (item) => Chip(
                  avatar: CircleAvatar(
                    child: Text(item.totalScore.toStringAsFixed(0)),
                  ),
                  label: Text(item.place.name),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _GeneratedDayPreview extends StatelessWidget {
  final PlannerDay day;

  const _GeneratedDayPreview({required this.day});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Day ${day.dayNumber}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (day.places.isEmpty)
                const Text('Free day / no place selected')
              else
                for (final scored in day.places)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scored.place.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${scored.place.category} • '
                                '${scored.place.estimatedVisitMinutes} min • '
                                'score ${scored.totalScore.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.62),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '\$${scored.place.estimatedCost.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 4),
              Text(
                'Estimated activity cost: '
                '\$${day.estimatedCost.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.13)
      ..strokeWidth = 1;

    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
