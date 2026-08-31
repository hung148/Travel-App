import 'package:flutter/material.dart';

class PlanTripPage extends StatefulWidget {
  const PlanTripPage({super.key});

  @override
  State<PlanTripPage> createState() => _PlanTripPageState();
}

class _PlanTripPageState extends State<PlanTripPage> {
  final destinationController = TextEditingController();
  final budgetController = TextEditingController();
  DateTimeRange? dates;
  int travelers = 1;

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
    if (selected != null) setState(() => dates = selected);
  }

  String _dateLabel() {
    if (dates == null) return 'Choose travel dates';
    String format(DateTime date) => '${date.month}/${date.day}/${date.year}';
    return '${format(dates!.start)} – ${format(dates!.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.travel_explore),
            SizedBox(width: 10),
            Text('Plan a trip'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {},
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
                    Text(
                      'Build your next trip',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 34),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start with the basics. Your preferences will help personalize the options later.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                          ),
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
                    const SizedBox(height: 20),
                    if (desktop)
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _MapPlaceholder()),
                          SizedBox(width: 20),
                          Expanded(flex: 2, child: _AiPlannerPlaceholder()),
                        ],
                      )
                    else ...[
                      const _MapPlaceholder(),
                      const SizedBox(height: 20),
                      const _AiPlannerPlaceholder(),
                    ],
                    const SizedBox(height: 20),
                    const _PlanPreviewPlaceholder(),
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
                  .map((field) => Padding(padding: const EdgeInsets.only(bottom: 14), child: field))
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
        height: 390,
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
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 52),
                    SizedBox(height: 12),
                    Text('Google Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Connect Maps here in the integration step'),
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

class _AiPlannerPlaceholder extends StatelessWidget {
  const _AiPlannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SizedBox(
        height: 342,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded),
                SizedBox(width: 10),
                Text('AI trip planner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Once your trip details are ready, I’ll suggest multiple plans based on your budget and preferences.',
                style: TextStyle(height: 1.45),
              ),
            ),
            const Spacer(),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('More food')),
                Chip(label: Text('Less walking')),
                Chip(label: Text('Make it cheaper')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Ask the planner to adjust your trip…',
                suffixIcon: IconButton(onPressed: null, icon: Icon(Icons.send_rounded)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanPreviewPlaceholder extends StatelessWidget {
  const _PlanPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.view_timeline_outlined),
              SizedBox(width: 10),
              Text('Plan preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Spacer(),
              Chip(label: Text('No plan generated yet')),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Your day-by-day itinerary will appear here after the planner generates options.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
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
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
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
