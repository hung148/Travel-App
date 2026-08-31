import 'package:flutter/material.dart';
import 'review_widget.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tokyo Adventure',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '5 days • Balanced plan • UI preview',
                              style: TextStyle(color: Color(0xFF667085)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/plan-trip'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit trip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = [
                        const _Metric(
                          label: 'Total budget',
                          value: '\$2,000',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        const _Metric(
                          label: 'Planned cost',
                          value: '\$1,820',
                          icon: Icons.receipt_long_outlined,
                        ),
                        const _Metric(
                          label: 'Activities',
                          value: '18',
                          icon: Icons.local_activity_outlined,
                        ),
                        const _Metric(
                          label: 'Travel time',
                          value: '3h 10m',
                          icon: Icons.route_outlined,
                        ),
                      ];
                      if (constraints.maxWidth < 720) {
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: cards
                              .map((e) => SizedBox(width: 220, child: e))
                              .toList(),
                        );
                      }
                      return Row(
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            Expanded(child: cards[i]),
                            if (i != cards.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 850) {
                        return const Column(
                          children: [
                            _BudgetCard(),
                            SizedBox(height: 16),
                            _ItineraryCard(),
                          ],
                        );
                      }
                      return const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 330, child: _BudgetCard()),
                          SizedBox(width: 16),
                          Expanded(child: _ItineraryCard()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const ReviewWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3E8F0)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF2C7BE5)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard();
  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Hotel', 650),
      ('Food & coffee', 520),
      ('Activities', 320),
      ('Transport', 180),
      ('Buffer', 150),
    ];
    return _Card(
      title: 'Budget breakdown',
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1)),
                    Text(
                      '\$${row.$2}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  const _ItineraryCard();
  @override
  Widget build(BuildContext context) {
    return const _Card(
      title: 'Day 1 — Shibuya & Harajuku',
      child: Column(
        children: [
          _TimelineItem(
            time: '10:00',
            title: 'Coffee & breakfast',
            detail: 'Specialty café • \$18',
          ),
          _TimelineItem(
            time: '11:30',
            title: 'Meiji Shrine',
            detail: 'Culture • Free • 12 min transfer',
          ),
          _TimelineItem(
            time: '13:30',
            title: 'Lunch',
            detail: 'Japanese restaurant • \$42',
          ),
          _TimelineItem(
            time: '15:00',
            title: 'Harajuku & Omotesando',
            detail: 'Shopping / walk • 8 min transfer',
          ),
          _TimelineItem(
            time: '18:30',
            title: 'Shibuya Sky',
            detail: 'Viewpoint • \$22',
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final String title;
  final String detail;
  const _TimelineItem({
    required this.time,
    required this.title,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C7BE5),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: CircleAvatar(radius: 5, backgroundColor: Color(0xFF2C7BE5)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(color: Color(0xFF667085))),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE3E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}
