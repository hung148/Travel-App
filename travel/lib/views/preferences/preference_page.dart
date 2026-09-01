import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';

class PreferencePage extends StatefulWidget {
  final String ownerId;
  final bool returnOnSave;

  const PreferencePage({
    super.key,
    required this.ownerId,
    this.returnOnSave = false,
  });

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _hasInitialized = false;

  Set<String> _experienceType = {};
  String? _activityLevel;
  String? _spendingStyle;
  Set<String> _interests = {};

  static const _totalQuestions = 4;

  final _experienceOptions = const [
    _Option('Nature', Icons.landscape_outlined),
    _Option('History', Icons.account_balance_outlined),
    _Option('Food', Icons.restaurant_outlined),
    _Option('Culture', Icons.museum_outlined),
    _Option('Adventure', Icons.hiking_outlined),
    _Option('Nightlife', Icons.nightlife_outlined),
    _Option('Shopping', Icons.shopping_bag_outlined),
    _Option('Beach', Icons.beach_access_outlined),
  ];

  final _activityOptions = const [
    _Option('Relaxed', Icons.spa_outlined, 'A slower pace with more free time'),
    _Option(
      'Moderate',
      Icons.directions_walk_outlined,
      'A comfortable mix of activities and breaks',
    ),
    _Option(
      'Very Active',
      Icons.directions_run_outlined,
      'Pack more experiences into each day',
    ),
  ];

  final _spendingOptions = const [
    _Option(
      'Budget',
      Icons.savings_outlined,
      'Prioritize value and local favorites',
    ),
    _Option(
      'Normal',
      Icons.account_balance_wallet_outlined,
      'Balance comfort, quality, and price',
    ),
    _Option(
      'Luxury',
      Icons.diamond_outlined,
      'Premium stays, dining, and experiences',
    ),
  ];

  final _interestOptions = const [
    _Option('Coffee', Icons.coffee_outlined),
    _Option('Local food', Icons.ramen_dining_outlined),
    _Option('Museums', Icons.museum_outlined),
    _Option('Photography', Icons.camera_alt_outlined),
    _Option('Shopping', Icons.shopping_bag_outlined),
    _Option('Attractions', Icons.attractions_outlined),
    _Option('Nightlife', Icons.local_bar_outlined),
    _Option('Hidden gems', Icons.explore_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PreferenceViewmodel>().loadPreferences(widget.ownerId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncFromViewModel(Preference? preference) {
    if (preference == null || _hasInitialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _experienceType = preference.experienceType.toSet();
        _activityLevel = preference.activityLevel.isEmpty
            ? null
            : preference.activityLevel;
        _spendingStyle = preference.spendingStyle.isEmpty
            ? null
            : preference.spendingStyle;
        _interests = preference.interests.toSet();
        _hasInitialized = true;
      });
    });
  }

  bool _isAnswered(int page) {
    switch (page) {
      case 0:
        return _experienceType.isNotEmpty;
      case 1:
        return _activityLevel?.isNotEmpty == true;
      case 2:
        return _spendingStyle?.isNotEmpty == true;
      case 3:
        return _interests.isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _next(PreferenceViewmodel vm) async {
    if (!_isAnswered(_currentPage)) return;

    if (_currentPage < _totalQuestions - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final preference = Preference(
      id: vm.preference?.id ?? widget.ownerId,
      ownerId: widget.ownerId,
      experienceType: _experienceType.toList(),
      activityLevel: _activityLevel!,
      spendingStyle: _spendingStyle!,
      interests: _interests.toList(),
    );

    await vm.savePreferences(preference);
  }

  Future<void> _back() async {
    if (_currentPage == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Consumer<PreferenceViewmodel>(
            builder: (context, vm, _) {
              _syncFromViewModel(vm.preference);

              if (vm.savedSuccessfully) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  vm.resetSavedFlag();
                  if (widget.returnOnSave) {
                    Navigator.pop(this.context, true);
                    return;
                  }
                  final authViewModel = context.read<AuthViewModel>();
                  await authViewModel.completeOnboarding();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(this.context, '/profile');
                });
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;

                  return Row(
                    children: [
                      if (isDesktop)
                        const Expanded(flex: 7, child: _PreferenceSidePanel()),
                      Expanded(
                        flex: 13,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 56 : 20,
                                vertical: isDesktop ? 36 : 20,
                              ),
                              child: Column(
                                children: [
                                  _Header(
                                    currentPage: _currentPage,
                                    totalQuestions: _totalQuestions,
                                    onBack: _currentPage > 0 ? _back : null,
                                  ),
                                  const SizedBox(height: 24),
                                  Expanded(
                                    child: vm.isLoading && !_hasInitialized
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : PageView(
                                            controller: _pageController,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            onPageChanged: (page) => setState(
                                              () => _currentPage = page,
                                            ),
                                            children: [
                                              _QuestionPage(
                                                eyebrow: 'TRAVEL STYLE',
                                                title:
                                                    'What kind of experiences do you want?',
                                                subtitle:
                                                    'Choose as many as you like. We’ll use these to rank places later.',
                                                child: _OptionGrid(
                                                  options: _experienceOptions,
                                                  selected: _experienceType,
                                                  onTap: (value) {
                                                    setState(() {
                                                      _experienceType.contains(
                                                            value,
                                                          )
                                                          ? _experienceType
                                                                .remove(value)
                                                          : _experienceType.add(
                                                              value,
                                                            );
                                                    });
                                                  },
                                                ),
                                              ),
                                              _QuestionPage(
                                                eyebrow: 'YOUR PACE',
                                                title:
                                                    'How active should your trip feel?',
                                                subtitle:
                                                    'This helps determine how many activities fit comfortably into each day.',
                                                child: _SingleChoiceList(
                                                  options: _activityOptions,
                                                  selected: _activityLevel,
                                                  onTap: (value) => setState(
                                                    () =>
                                                        _activityLevel = value,
                                                  ),
                                                ),
                                              ),
                                              _QuestionPage(
                                                eyebrow: 'SPENDING STYLE',
                                                title:
                                                    'How do you like to spend while traveling?',
                                                subtitle:
                                                    'This is a preference, not your final trip budget. You’ll enter the real budget when planning a trip.',
                                                child: _SingleChoiceList(
                                                  options: _spendingOptions,
                                                  selected: _spendingStyle,
                                                  onTap: (value) => setState(
                                                    () =>
                                                        _spendingStyle = value,
                                                  ),
                                                ),
                                              ),
                                              _QuestionPage(
                                                eyebrow: 'INTERESTS',
                                                title:
                                                    'What do you enjoy most when you travel?',
                                                subtitle:
                                                    'Pick a few favorites so recommendations feel more personal.',
                                                child: _OptionGrid(
                                                  options: _interestOptions,
                                                  selected: _interests,
                                                  onTap: (value) {
                                                    setState(() {
                                                      _interests.contains(value)
                                                          ? _interests.remove(
                                                              value,
                                                            )
                                                          : _interests.add(
                                                              value,
                                                            );
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  if (vm.errorMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Text(
                                        vm.errorMessage!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      if (_currentPage > 0) ...[
                                        OutlinedButton(
                                          onPressed: vm.isLoading
                                              ? null
                                              : _back,
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 14,
                                            ),
                                            child: Text('Back'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: SizedBox(
                                          height: 54,
                                          child: FilledButton(
                                            onPressed:
                                                vm.isLoading ||
                                                    !_isAnswered(_currentPage)
                                                ? null
                                                : () => _next(vm),
                                            child: vm.isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : Text(
                                                    _currentPage ==
                                                            _totalQuestions - 1
                                                        ? 'Save preferences'
                                                        : 'Continue',
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int currentPage;
  final int totalQuestions;
  final VoidCallback? onBack;

  const _Header({
    required this.currentPage,
    required this.totalQuestions,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentPage + 1) / totalQuestions;

    return Row(
      children: [
        if (onBack != null) ...[
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Travel preferences',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('${currentPage + 1} / $totalQuestions'),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferenceSidePanel extends StatelessWidget {
  const _PreferenceSidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.travel_explore, color: Colors.white, size: 34),
          const Spacer(),
          const Text(
            'Make every trip\nfeel like yours.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Your preferences help the planner understand what deserves more of your time and budget.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const Spacer(),
          Text(
            'You can change these later.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
          ),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  const _QuestionPage({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  final List<_Option> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  const _OptionGrid({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650
            ? 4
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        const gap = 12.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: options.map((option) {
            final isSelected = selected.contains(option.label);
            return SizedBox(
              width: itemWidth,
              child: _ChoiceCard(
                option: option,
                selected: isSelected,
                onTap: () => onTap(option.label),
                compact: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SingleChoiceList extends StatelessWidget {
  final List<_Option> options;
  final String? selected;
  final ValueChanged<String> onTap;

  const _SingleChoiceList({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options
          .map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChoiceCard(
                option: option,
                selected: selected == option.label,
                onTap: () => onTap(option.label),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final _Option option;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _ChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected
          ? primary.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? primary
                  : Theme.of(context).dividerColor.withValues(alpha: 0.42),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? primary : primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? Colors.white : primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (option.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        option.description!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact)
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? primary : Theme.of(context).dividerColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option {
  final String label;
  final IconData icon;
  final String? description;

  const _Option(this.label, this.icon, [this.description]);
}
