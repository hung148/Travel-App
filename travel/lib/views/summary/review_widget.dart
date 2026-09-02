import 'package:flutter/material.dart';

class ReviewWidget extends StatefulWidget {
  const ReviewWidget({super.key});

  @override
  State<ReviewWidget> createState() => _ReviewWidgetState();
}

class _ReviewWidgetState extends State<ReviewWidget> {
  int _rating = 0;
  final Set<String> _liked = {};
  final Set<String> _improve = {};

  static const likedOptions = [
    'Food',
    'Hotel',
    'Activities',
    'Route',
    'Schedule',
  ];
  static const improveOptions = [
    'Too expensive',
    'Too busy',
    'Too much walking',
    'Food',
    'Hotel',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How does this plan look?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Your feedback can improve this plan and future recommendations.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: const Color(0xFFF5B942),
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'What did you like most?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: likedOptions
                .map(
                  (option) => FilterChip(
                    selected: _liked.contains(option),
                    label: Text(option),
                    onSelected: (value) => setState(
                      () => value ? _liked.add(option) : _liked.remove(option),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          const Text(
            'What could be better?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: improveOptions
                .map(
                  (option) => FilterChip(
                    selected: _improve.contains(option),
                    label: Text(option),
                    onSelected: (value) => setState(
                      () => value
                          ? _improve.add(option)
                          : _improve.remove(option),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _rating == 0
                ? null
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Feedback saved locally for UI demo.'),
                    ),
                  ),
            icon: const Icon(Icons.favorite_outline_rounded),
            label: const Text('Submit feedback'),
          ),
        ],
      ),
    );
  }
}
