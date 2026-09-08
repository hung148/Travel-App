import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/models/feedback.dart' as model;
import 'package:travel/service/feedback_service.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';

class SavedTripReview extends StatelessWidget {
  const SavedTripReview({super.key, required this.tripId});

  final String? tripId;

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthViewModel>().user?.uid;
    return ReviewWidget(
      onSubmit: tripId == null || userId == null
          ? null
          : (rating, best, worst) => FeedbackService().saveFeedback(
              feedback: model.Feedback(
                // One review per account and trip; retries update that review.
                id: '${tripId}_$userId',
                userId: userId,
                tripId: tripId!,
                rating: rating.toDouble(),
                best: best,
                worst: worst,
              ),
            ),
    );
  }
}

class ReviewWidget extends StatefulWidget {
  const ReviewWidget({super.key, required this.onSubmit});

  final Future<void> Function(int rating, String best, String worst)? onSubmit;

  @override
  State<ReviewWidget> createState() => _ReviewWidgetState();
}

class _ReviewWidgetState extends State<ReviewWidget> {
  int _rating = 0;
  final Set<String> _liked = {};
  final Set<String> _improve = {};
  bool _saving = false;
  String? _saveError;

  Future<void> _submit() async {
    final submit = widget.onSubmit;
    if (submit == null || _saving || _rating == 0) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await submit(_rating, _liked.join(', '), _improve.join(', '));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Feedback saved.')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Could not save feedback. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
          color: Theme.of(context).dividerColor.withValues(alpha: 0.78),
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
          if (widget.onSubmit == null)
            const Text(
              'Save your trip and sign in before submitting feedback.',
            ),
          if (_saveError != null)
            Text(
              _saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton.icon(
            onPressed: _rating == 0 || _saving || widget.onSubmit == null
                ? null
                : _submit,
            icon: const Icon(Icons.favorite_outline_rounded),
            label: Text(_saving ? 'Saving feedback...' : 'Submit feedback'),
          ),
        ],
      ),
    );
  }
}
