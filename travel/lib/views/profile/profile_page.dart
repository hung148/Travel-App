import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/preference_viewmodel.dart';
import '../../viewmodels/trip_viewmodel.dart';
import '../preferences/preference_page.dart';
import '../../models/preference/preferences.dart';
import '../../models/trip/trip.dart';
import '../../models/user.dart';
import '../../widgets/trip_history_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _requestedData = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final preferenceViewModel = context.watch<PreferenceViewmodel>();
    final tripViewModel = context.watch<TripViewModel>();
    if (!_requestedData) {
      _requestedData = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PreferenceViewmodel>().loadPreferences(user.uid);
        context.read<TripViewModel>().listenToTripHistory(user.uid);
      });
    }
    final preference =
        preferenceViewModel.preference ??
        Preference(
          id: user.uid,
          ownerId: user.uid,
          experienceType: const [],
          activityLevel: '',
          spendingStyle: '',
          interests: const [],
        );
    final trips = tripViewModel.tripHistory;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  _TopBar(user: user),
                  const SizedBox(height: 30),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Hero(user: user),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 850) {
                                return Column(
                                  children: [
                                    _TravelStyleCard(preference: preference),
                                    const SizedBox(height: 16),
                                    _UpcomingCard(trips: trips),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _TravelStyleCard(
                                      preference: preference,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: _UpcomingCard(trips: trips)),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Your trips',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Review past adventures or continue planning an upcoming trip.',
                            style: TextStyle(color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 16),
                          TripHistoryWidget(
                            trips: trips,
                            onTripTap: (_) =>
                                Navigator.pushNamed(context, '/summary'),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppUser user;
  const _TopBar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2C7BE5),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.travel_explore_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'Travel App',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            final auth = context.read<AuthViewModel>();
            final uid = auth.user?.uid ?? user.uid;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PreferencePage(ownerId: uid)),
            );
          },
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Preferences'),
        ),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: () => context.read<AuthViewModel>().logout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          backgroundColor: const Color(0xFFEAF2FF),
          foregroundColor: const Color(0xFF2C7BE5),
          child: Text(
            (user.name.trim().isEmpty ? user.email : user.name)
                .substring(0, 1)
                .toUpperCase(),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final AppUser user;
  const _Hero({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF143B73), Color(0xFF2C7BE5)],
        ),
      ),
      child: Wrap(
        runSpacing: 20,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${user.name.split(' ').first} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tell us where you want to go next. We’ll help organize the budget, places, and schedule.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/plan-trip'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF143B73),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Plan a new trip',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelStyleCard extends StatelessWidget {
  final Preference preference;
  const _TravelStyleCard({required this.preference});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      ...preference.experienceType,
      preference.activityLevel,
      preference.spendingStyle,
      ...preference.interests,
    ];
    return _Panel(
      title: 'Your travel style',
      subtitle: 'Used to personalize future plans.',
      trailing: TextButton(
        onPressed: () {
          final auth = context.read<AuthViewModel>();
          final uid = auth.user?.uid ?? preference.ownerId;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PreferencePage(ownerId: uid)),
          );
        },
        child: const Text('Edit'),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((text) => Chip(label: Text(text))).toList(),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final List<Trip> trips;
  const _UpcomingCard({required this.trips});

  @override
  Widget build(BuildContext context) {
    Trip? upcoming;
    for (final trip in trips) {
      if (trip.status.toLowerCase() == 'upcoming') {
        upcoming = trip;
        break;
      }
    }
    return _Panel(
      title: 'Upcoming trip',
      subtitle: upcoming == null
          ? 'Nothing planned yet.'
          : '${upcoming.destination} • ${upcoming.days} days',
      trailing: upcoming == null
          ? null
          : TextButton(
              onPressed: () => Navigator.pushNamed(context, '/summary'),
              child: const Text('Open'),
            ),
      child: upcoming == null
          ? const Text('Start a new plan to see it here.')
          : Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF2C7BE5),
                ),
                const SizedBox(width: 10),
                Text(
                  'Budget \$${upcoming.budget.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          Text(subtitle, style: const TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
