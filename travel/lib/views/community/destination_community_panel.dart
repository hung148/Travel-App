import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community/destination_review.dart';
import '../../models/community/destination_tip.dart';
import '../../models/trip/trip.dart';
import '../../models/trip/trip_segment.dart';
import '../../service/community/community_service.dart';
import '../../viewmodels/auth_viewmodel.dart';

class DestinationCommunityPanel extends StatefulWidget {
  const DestinationCommunityPanel({
    super.key,
    required this.trip,
    this.showComposer = true,
  });

  final Trip trip;
  final bool showComposer;

  @override
  State<DestinationCommunityPanel> createState() =>
      _DestinationCommunityPanelState();
}

class _DestinationCommunityPanelState extends State<DestinationCommunityPanel> {
  final _service = CommunityService();
  final _reviewController = TextEditingController();
  final _foodController = TextEditingController();
  final _placesController = TextEditingController();
  final _tipController = TextEditingController();

  late TripSegment _selectedSegment;
  int _rating = 5;
  bool _anonymous = false;
  bool _savingReview = false;
  bool _savingTip = false;
  String _tipCategory = 'food';
  final Set<String> _highlights = {'Food'};

  TripSegment get _initialSegment {
    return widget.trip.segments.isNotEmpty
        ? widget.trip.segments.first
        : TripSegment(
            id: widget.trip.id,
            destination: widget.trip.destination,
            destinationPlaceId: null,
            startDate: widget.trip.startDate ?? DateTime.now(),
            endDate: widget.trip.endDate ?? DateTime.now(),
            allocatedBudget: widget.trip.budget,
          );
  }

  @override
  void initState() {
    super.initState();
    _selectedSegment = _initialSegment;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _foodController.dispose();
    _placesController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segments = widget.trip.segments.isEmpty
        ? [_selectedSegment]
        : widget.trip.segments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommunityHero(destination: _selectedSegment.destination),
        const SizedBox(height: 14),
        if (segments.length > 1) ...[
          _DestinationSelector(
            segments: segments,
            selected: _selectedSegment,
            onChanged: (segment) => setState(() => _selectedSegment = segment),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.showComposer) ...[
          _ReviewComposer(
            rating: _rating,
            anonymous: _anonymous,
            saving: _savingReview,
            highlights: _highlights,
            reviewController: _reviewController,
            foodController: _foodController,
            placesController: _placesController,
            onRatingChanged: (value) => setState(() => _rating = value),
            onAnonymousChanged: (value) => setState(() => _anonymous = value),
            onHighlightChanged: _toggleHighlight,
            onSubmit: _publishReview,
          ),
          const SizedBox(height: 14),
        ],
        _CommunityFeed(
          service: _service,
          segment: _selectedSegment,
          tipController: _tipController,
          tipCategory: _tipCategory,
          savingTip: _savingTip,
          onTipCategoryChanged: (value) => setState(() => _tipCategory = value),
          onPublishTip: _publishTip,
        ),
      ],
    );
  }

  void _toggleHighlight(String value, bool selected) {
    setState(() {
      selected ? _highlights.add(value) : _highlights.remove(value);
    });
  }

  Future<void> _publishReview() async {
    final user = context.read<AuthViewModel>().user;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? firebaseUser?.uid;
    if (uid == null) {
      _showMessage('Please sign in before publishing a review.');
      return;
    }
    final body = _reviewController.text.trim();
    if (body.length < 12) {
      _showMessage('Write a little more so other travelers can learn from it.');
      return;
    }

    setState(() => _savingReview = true);
    try {
      await _service.publishReview(
        DestinationReview(
          id: _documentId(uid),
          ownerId: uid,
          tripId: widget.trip.id,
          destinationName: _selectedSegment.destination,
          destinationKey: DestinationReview.normalizeDestinationKey(
            _selectedSegment.destination,
          ),
          destinationPlaceId: _selectedSegment.destinationPlaceId,
          displayName: (user?.name.trim().isNotEmpty == true)
              ? user!.name.trim()
              : 'Traveler',
          isAnonymous: _anonymous,
          rating: _rating,
          tripStyleTags: _highlights.toList()..sort(),
          highlights: _highlights.toList()..sort(),
          mustTryFoods: _splitList(_foodController.text),
          recommendedPlaces: _splitList(_placesController.text),
          body: body,
        ),
      );
      _reviewController.clear();
      _foodController.clear();
      _placesController.clear();
      if (mounted) _showMessage('Published to the destination community.');
    } catch (error) {
      if (mounted) _showMessage('Could not publish review: $error');
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  Future<void> _publishTip() async {
    final user = context.read<AuthViewModel>().user;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? firebaseUser?.uid;
    if (uid == null) {
      _showMessage('Please sign in before sharing a tip.');
      return;
    }
    final text = _tipController.text.trim();
    if (text.length < 6) {
      _showMessage('Add a more useful tip first.');
      return;
    }

    setState(() => _savingTip = true);
    try {
      await _service.publishTip(
        DestinationTip(
          id: _documentId(uid),
          ownerId: uid,
          destinationName: _selectedSegment.destination,
          destinationKey: DestinationTip.normalizeDestinationKey(
            _selectedSegment.destination,
          ),
          destinationPlaceId: _selectedSegment.destinationPlaceId,
          displayName: (user?.name.trim().isNotEmpty == true)
              ? user!.name.trim()
              : 'Traveler',
          isAnonymous: _anonymous,
          category: _tipCategory,
          text: text,
        ),
      );
      _tipController.clear();
      if (mounted) _showMessage('Tip added for future travelers.');
    } catch (error) {
      if (mounted) _showMessage('Could not add tip: $error');
    } finally {
      if (mounted) setState(() => _savingTip = false);
    }
  }

  List<String> _splitList(String value) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(10)
        .toList();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _documentId(String uid) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${uid}_$timestamp';
  }
}

class _CommunityHero extends StatelessWidget {
  const _CommunityHero({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return _CommunityCard(
      child: Row(
        children: [
          const _IconBox(icon: Icons.forum_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _EyebrowText('DESTINATION COMMUNITY'),
                const SizedBox(height: 5),
                Text(
                  'Real traveler notes for $destination',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF201A17),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Publish what actually mattered: must-try food, memorable places, local tips, and honest warnings.',
                  style: TextStyle(color: Color(0xFF6B5A52), fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationSelector extends StatelessWidget {
  const _DestinationSelector({
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<TripSegment> segments;
  final TripSegment selected;
  final ValueChanged<TripSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final segment in segments)
          ChoiceChip(
            selected: segment.id == selected.id,
            label: Text(segment.destination),
            onSelected: (_) => onChanged(segment),
          ),
      ],
    );
  }
}

class _ReviewComposer extends StatelessWidget {
  const _ReviewComposer({
    required this.rating,
    required this.anonymous,
    required this.saving,
    required this.highlights,
    required this.reviewController,
    required this.foodController,
    required this.placesController,
    required this.onRatingChanged,
    required this.onAnonymousChanged,
    required this.onHighlightChanged,
    required this.onSubmit,
  });

  final int rating;
  final bool anonymous;
  final bool saving;
  final Set<String> highlights;
  final TextEditingController reviewController;
  final TextEditingController foodController;
  final TextEditingController placesController;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<bool> onAnonymousChanged;
  final void Function(String value, bool selected) onHighlightChanged;
  final VoidCallback onSubmit;

  static const options = [
    'Beach',
    'Food',
    'Nature',
    'Culture',
    'Shopping',
    'Nightlife',
    'Family',
    'Budget',
  ];

  @override
  Widget build(BuildContext context) {
    return _CommunityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EyebrowText('PUBLISH A REVIEW'),
          const SizedBox(height: 8),
          Text(
            'What should the next traveler know?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 1; index <= 5; index++)
                IconButton(
                  tooltip: '$index stars',
                  onPressed: () => onRatingChanged(index),
                  icon: Icon(
                    index <= rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFD68A2D),
                    size: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  selected: highlights.contains(option),
                  label: Text(option),
                  onSelected: (selected) =>
                      onHighlightChanged(option, selected),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: reviewController,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Review',
              hintText:
                  'Example: Son Tra was worth the early start, the beach felt peaceful, and bun cha ca was the must-try dish.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: foodController,
            decoration: const InputDecoration(
              labelText: 'Must-try food',
              hintText: 'Bun cha ca, banh xeo, coffee...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: placesController,
            decoration: const InputDecoration(
              labelText: 'Recommended places',
              hintText: 'Son Tra, My Khe Beach, Vincom Plaza...',
            ),
          ),
          SwitchListTile.adaptive(
            value: anonymous,
            onChanged: onAnonymousChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text('Post as anonymous traveler'),
            subtitle: const Text('Your review still belongs to your account.'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSubmit,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.public_rounded),
            label: const Text('Publish destination review'),
          ),
        ],
      ),
    );
  }
}

class _CommunityFeed extends StatelessWidget {
  const _CommunityFeed({
    required this.service,
    required this.segment,
    required this.tipController,
    required this.tipCategory,
    required this.savingTip,
    required this.onTipCategoryChanged,
    required this.onPublishTip,
  });

  final CommunityService service;
  final TripSegment segment;
  final TextEditingController tipController;
  final String tipCategory;
  final bool savingTip;
  final ValueChanged<String> onTipCategoryChanged;
  final VoidCallback onPublishTip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TipComposer(
          controller: tipController,
          category: tipCategory,
          saving: savingTip,
          onCategoryChanged: onTipCategoryChanged,
          onPublish: onPublishTip,
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<DestinationTip>>(
          stream: service.watchTips(
            destinationName: segment.destination,
            destinationPlaceId: segment.destinationPlaceId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _CommunityCard(
                child: _SoftEmpty(
                  title: 'Tips are unavailable right now',
                  message:
                      'The trip is saved. Community tips will appear here when the feed is ready.',
                ),
              );
            }
            final tips = snapshot.data ?? const <DestinationTip>[];
            return _CommunityCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    title: 'Destination tips',
                    icon: Icons.lightbulb_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator()
                  else if (tips.isEmpty)
                    const _SoftEmpty(
                      title: 'No tips yet',
                      message:
                          'Be the first person to make this destination easier.',
                    )
                  else
                    ...tips.take(6).map((tip) => _TipTile(tip: tip)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<DestinationReview>>(
          stream: service.watchReviews(
            destinationName: segment.destination,
            destinationPlaceId: segment.destinationPlaceId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _CommunityCard(
                child: _SoftEmpty(
                  title: 'Reviews are unavailable right now',
                  message:
                      'The trip is saved. Public destination reviews will appear here when the feed is ready.',
                ),
              );
            }
            final reviews = snapshot.data ?? const <DestinationReview>[];
            return _CommunityCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    title: 'Traveler reviews',
                    icon: Icons.rate_review_outlined,
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator()
                  else if (reviews.isEmpty)
                    const _SoftEmpty(
                      title: 'No public reviews yet',
                      message:
                          'Once travelers publish feedback, this becomes a useful local guide.',
                    )
                  else
                    ...reviews
                        .take(5)
                        .map((review) => _ReviewTile(review: review)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TipComposer extends StatelessWidget {
  const _TipComposer({
    required this.controller,
    required this.category,
    required this.saving,
    required this.onCategoryChanged,
    required this.onPublish,
  });

  final TextEditingController controller;
  final String category;
  final bool saving;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onPublish;

  static const categories = {
    'food': 'Food',
    'place': 'Place',
    'warning': 'Warning',
    'transport': 'Transport',
    'general': 'General',
  };

  @override
  Widget build(BuildContext context) {
    return _CommunityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Add a quick tip',
            icon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in categories.entries)
                ChoiceChip(
                  selected: category == entry.key,
                  label: Text(entry.value),
                  onSelected: (_) => onCategoryChanged(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Tip',
              hintText: 'Example: Go before 8 AM if you want quieter photos.',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving ? null : onPublish,
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Share tip'),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final DestinationReview review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFBF7F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1B9AA)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.visibleName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _Stars(value: review.rating),
                ],
              ),
              const SizedBox(height: 8),
              Text(review.body, style: const TextStyle(fontSize: 15.5)),
              if (review.mustTryFoods.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InlineTags(
                  icon: Icons.restaurant_menu_rounded,
                  values: review.mustTryFoods,
                ),
              ],
              if (review.recommendedPlaces.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InlineTags(
                  icon: Icons.place_outlined,
                  values: review.recommendedPlaces,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({required this.tip});

  final DestinationTip tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: _iconFor(tip.category), compact: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.text,
                  style: const TextStyle(
                    color: Color(0xFF201A17),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_labelFor(tip.category)} • ${tip.visibleName}',
                  style: const TextStyle(color: Color(0xFF75645C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'food' => Icons.restaurant_menu_rounded,
      'place' => Icons.place_outlined,
      'warning' => Icons.warning_amber_rounded,
      'transport' => Icons.directions_bus_outlined,
      _ => Icons.lightbulb_outline_rounded,
    };
  }

  String _labelFor(String category) {
    return switch (category) {
      'food' => 'Food',
      'place' => 'Place',
      'warning' => 'Warning',
      'transport' => 'Transport',
      _ => 'General',
    };
  }
}

class _InlineTags extends StatelessWidget {
  const _InlineTags({required this.icon, required this.values});

  final IconData icon;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5C4034)),
        for (final value in values.take(5)) _SmallPill(value),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFD68A2D), size: 18),
        const SizedBox(width: 3),
        Text('$value.0', style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD1B9AA)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF5C4034)),
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _SoftEmpty extends StatelessWidget {
  const _SoftEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1B9AA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _IconBox(icon: Icons.travel_explore_rounded, compact: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(color: Color(0xFF75645C)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB99A88), width: 1.35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A211D).withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.compact = false});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6B4A3B),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: Colors.white, size: compact ? 18 : 22),
    );
  }
}

class _EyebrowText extends StatelessWidget {
  const _EyebrowText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B4A3B),
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}
