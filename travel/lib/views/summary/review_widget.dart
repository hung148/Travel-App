import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community/destination_review.dart';
import '../../models/feedback.dart' as model;
import '../../models/trip/trip.dart';
import '../../service/community/community_service.dart';
import '../../service/feedback_service.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ReviewWidget extends StatefulWidget {
  const ReviewWidget({super.key, this.trip, this.feedbackService});

  final Trip? trip;
  final FeedbackService? feedbackService;

  @override
  State<ReviewWidget> createState() => _ReviewWidgetState();
}

class _ReviewWidgetState extends State<ReviewWidget> {
  int _rating = 0;
  final Set<String> _liked = {};
  final Set<String> _improve = {};
  final _reviewController = TextEditingController();
  bool _saving = false;
  String? _saveError;

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
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

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
            'Write your trip review',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep it private for personalization, or publish it so future travelers can learn from your experience.',
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
          const SizedBox(height: 18),
          const Text(
            'Review passage',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewController,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Your honest review',
              hintText:
                  'Example: The beach was beautiful, people were kind, and bun cha ca was absolutely worth trying.',
            ),
          ),
          const SizedBox(height: 20),
          if (widget.trip == null)
            const Text('Save your trip before submitting feedback.'),
          if (_saveError != null)
            Text(
              _saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton.icon(
            onPressed: _rating == 0 || _saving || widget.trip == null
                ? null
                : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.favorite_outline_rounded),
            label: const Text('Submit feedback'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving || _rating == 0 || widget.trip == null) return;
    final user = context.read<AuthViewModel>().user;
    final uid = user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showMessage('Please sign in before submitting feedback.');
      return;
    }

    final reviewText = _reviewController.text.trim();
    if (reviewText.length < 8) {
      _showMessage('Please write a short review passage first.');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    final publish = await _askPublishChoice();
    if (!mounted) return;
    if (publish == null) {
      setState(() => _saving = false);
      return;
    }

    final trip = widget.trip;
    if (trip == null) {
      _showMessage(
        publish
            ? 'Save this trip first, then publish the review from the saved trip page.'
            : 'Save this trip first so private feedback can attach to it.',
      );
      return;
    }

    try {
      await (widget.feedbackService ?? FeedbackService()).saveFeedback(
        feedback: model.Feedback(
          id: _documentId(uid),
          userId: uid,
          tripId: trip.id,
          rating: _rating.toDouble(),
          best: [
            if (_liked.isNotEmpty) 'Liked: ${_liked.join(', ')}',
            reviewText,
          ].join('\n'),
          worst: _improve.isEmpty ? '' : _improve.join(', '),
        ),
      );
      if (!mounted) return;

      if (publish) {
        final segment = trip.segments.isNotEmpty ? trip.segments.first : null;
        final destinationName = segment?.destination ?? trip.destination;
        await CommunityService().publishReview(
          DestinationReview(
            id: _documentId(uid),
            ownerId: uid,
            tripId: trip.id,
            destinationName: destinationName,
            destinationKey: DestinationReview.normalizeDestinationKey(
              destinationName,
            ),
            destinationPlaceId: segment?.destinationPlaceId,
            displayName: (user?.name.trim().isNotEmpty == true)
                ? user!.name.trim()
                : 'Traveler',
            isAnonymous: false,
            rating: _rating,
            tripStyleTags: _liked.toList()..sort(),
            highlights: _liked.toList()..sort(),
            body: reviewText,
          ),
        );
        _showMessage('Feedback saved and published publicly.');
      } else {
        _showMessage('Private feedback saved.');
      }

      if (!mounted) return;
      _reviewController.clear();
      setState(() {
        _rating = 0;
        _liked.clear();
        _improve.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveError = 'Could not save feedback. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _askPublishChoice() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make this review public?'),
        content: const Text(
          'Public reviews appear in the destination community so other travelers can use your experience. Private feedback only improves your own planning history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep private'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish public'),
          ),
        ],
      ),
    );
  }

  String _documentId(String uid) {
    return '${widget.trip!.id}_$uid';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
