import 'package:flutter/material.dart';
import 'ai_chat_widget.dart';

class PlanTripPage extends StatefulWidget {
  const PlanTripPage({super.key});

  @override
  State<PlanTripPage> createState() => _PlanTripPageState();
}

class _PlanTripPageState extends State<PlanTripPage> {
  final destinationController = TextEditingController(text: 'Tokyo, Japan');
  final budgetController = TextEditingController(text: '2000');

  DateTimeRange? dates;
  int travelers = 2;
  bool planGenerated = false;
  String selectedPlan = 'Balanced';

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

  void _generatePlan() {
    final destination = destinationController.text.trim();
    final budget = double.tryParse(budgetController.text.trim());

    if (destination.isEmpty || budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination and valid budget first.')),
      );
      return;
    }

    setState(() => planGenerated = true);
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
                const SnackBar(content: Text('Draft saved locally for this UI demo.')),
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
                                    ?.copyWith(fontSize: 34, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choose the basics, generate a plan, then negotiate changes with the AI planner.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                            onPressed: _generatePlan,
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(planGenerated ? 'Regenerate plan' : 'Generate plan'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
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
                      onTravelersChanged: (value) => setState(() => travelers = value),
                    ),
                    if (!desktop) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _generatePlan,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(planGenerated ? 'Regenerate plan' : 'Generate plan'),
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
                                  if (!planGenerated) setState(() => planGenerated = true);
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
                            if (!planGenerated) setState(() => planGenerated = true);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _PlanOptions(
                      selectedPlan: selectedPlan,
                      enabled: planGenerated,
                      onSelected: (value) => setState(() => selectedPlan = value),
                    ),
                    const SizedBox(height: 20),
                    _PlanPreview(
                      generated: planGenerated,
                      selectedPlan: selectedPlan,
                      destination: destinationController.text.trim().isEmpty
                          ? 'your destination'
                          : destinationController.text.trim(),
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
                label: Align(alignment: Alignment.centerLeft, child: Text(dateLabel)),
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
                      onPressed: travelers > 1 ? () => onTravelersChanged(travelers - 1) : null,
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
                  .map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: field,
                      ))
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  child: CustomPaint(painter: _MapGridPainter()),
                ),
              ),
              const Positioned(left: 110, top: 135, child: _MapPin(number: '1')),
              const Positioned(left: 245, top: 225, child: _MapPin(number: '2')),
              const Positioned(right: 145, top: 115, child: _MapPin(number: '3')),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 52),
                    SizedBox(height: 12),
                    Text('Google Map Preview',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
      ('Relaxed', '\$1,650', 'Fewer stops • more free time', Icons.spa_outlined),
      ('Balanced', '\$1,820', 'Best mix of places and rest', Icons.balance_outlined),
      ('Explorer', '\$1,940', 'More activities • fuller days', Icons.explore_outlined),
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded),
              const SizedBox(width: 10),
              const Text('Choose a plan style',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Chip(label: Text(enabled ? '3 mock options ready' : 'Generate a plan first')),
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
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected && enabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor.withValues(alpha: 0.45),
                            width: selected && enabled ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(plan.$4,
                                color: enabled
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(plan.$1,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900, fontSize: 16)),
                                  const SizedBox(height: 3),
                                  Text(plan.$3,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                            Text(plan.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
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
  final VoidCallback onGenerate;
  final VoidCallback onReview;

  const _PlanPreview({
    required this.generated,
    required this.selectedPlan,
    required this.destination,
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
              const Text('Plan preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Chip(label: Text(generated ? '$selectedPlan plan' : 'No plan generated yet')),
            ],
          ),
          const SizedBox(height: 18),
          if (!generated) ...[
            Text(
              'Generate a plan to preview a day-by-day itinerary for $destination.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate mock plan'),
            ),
          ] else ...[
            const _DayPreview(
              day: 'Day 1',
              title: 'Shibuya & Harajuku',
              items: [
                '10:00  Coffee & breakfast',
                '11:30  Meiji Shrine',
                '13:30  Japanese lunch',
                '15:00  Harajuku & Omotesando',
                '18:30  Shibuya Sky',
              ],
            ),
            const Divider(height: 32),
            const _DayPreview(
              day: 'Day 2',
              title: 'Asakusa & Ueno',
              items: [
                '09:30  Senso-ji',
                '11:30  Nakamise shopping',
                '13:00  Local lunch',
                '15:00  Ueno Park',
              ],
            ),
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

class _DayPreview extends StatelessWidget {
  final String day;
  final String title;
  final List<String> items;

  const _DayPreview({required this.day, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(day, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(item),
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
