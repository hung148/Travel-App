import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/preference_viewmodel.dart';
import '../../viewmodels/trip_viewmodel.dart';
import '../preferences/preference_page.dart';
import '../saved_trip/saved_trip_details_page.dart';
import '../../models/preference/preferences.dart';
import '../../models/trip/trip.dart';
import '../../models/user.dart';
import '../../widgets/trip_history_widget.dart';

/// Name to greet the user with.
///
/// Right after sign up the auth stream can emit before the display name and
/// the Firestore document have been written, so [AppUser.name] is briefly
/// empty. Falling back to the email keeps the greeting from reading
/// "Welcome back,  👋".
String _displayName(AppUser user) {
  final name = user.name.trim();
  if (name.isNotEmpty) return name.split(' ').first;

  final email = user.email.trim();
  if (email.isNotEmpty) return email.split('@').first;

  return 'traveler';
}

/// Single letter for the avatar, safe on an empty name and email.
String _avatarInitial(AppUser user) {
  final source = _displayName(user);
  return source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
}

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                                    _UpcomingCard(
                                      trips: trips,
                                      onOpen: _openSavedTrip,
                                    ),
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
                                  Expanded(
                                    child: _UpcomingCard(
                                      trips: trips,
                                      onOpen: _openSavedTrip,
                                    ),
                                  ),
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
                            onTripTap: _openSavedTrip,
                            onTripDelete: _deleteTrip,
                            onTripDuplicate: _duplicateTrip,
                          ),
                          const SizedBox(height: 40),
                          _DangerZone(onDelete: _confirmDeleteAccount),
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

  Future<void> _openSavedTrip(Trip trip) async {
    final tripViewModel = context.read<TripViewModel>();
    await tripViewModel.loadTripById(trip.id);
    if (!mounted) return;
    if (tripViewModel.currentTrip == null ||
        tripViewModel.draftSegments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tripViewModel.errorMessage ??
                'This saved trip has no planner data yet.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SavedTripDetailsPage(trip: trip)),
    );
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'Delete the ${trip.destination} trip from ${trip.startDate == null ? 'your dashboard' : MaterialLocalizations.of(context).formatMediumDate(trip.startDate!)}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final viewModel = context.read<TripViewModel>();
    await viewModel.deleteTrip(trip.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          viewModel.errorMessage == null
              ? 'Trip deleted.'
              : 'Could not delete trip: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  /// Opens the delete-account dialog.
  ///
  /// Nothing happens here afterwards on purpose: a successful deletion makes
  /// AuthGate replace this whole page with the login screen, so by the time
  /// the dialog closes this State is unmounted and could not show a message
  /// even if it wanted to. The dialog reports its own outcome.
  Future<void> _confirmDeleteAccount() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }

  Future<void> _duplicateTrip(Trip trip) async {
    final copy = trip.copyWith(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      title: '${trip.title ?? trip.destination} (Copy)',
      status: 'draft',
      createdAt: null,
      updatedAt: null,
    );
    final viewModel = context.read<TripViewModel>();
    await viewModel.createTrip(copy);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Duplicated ${trip.title ?? trip.destination}.')),
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
            color: Theme.of(context).colorScheme.primary,
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: Text(_avatarInitial(user)),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F1EB), Color(0xFFEDE0D6)],
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
                  'Welcome back, ${_displayName(user)} 👋',
                  style: const TextStyle(
                    color: Color(0xFF1C1816),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tell us where you want to go next. We’ll help organize the budget, places, and schedule.',
                  style: TextStyle(
                    color: Color(0xFF6F5B50),
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
              backgroundColor: const Color(0xFF241C18),
              foregroundColor: Colors.white,
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
    // styleTags already merges experienceType and interests and drops
    // duplicates; the pace and spending answers are single values.
    final chips = <String>[
      ...preference.styleTags,
      preference.activityLevel,
      preference.spendingStyle,
    ].where((label) => label.trim().isNotEmpty).toList();
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
  final ValueChanged<Trip> onOpen;
  const _UpcomingCard({required this.trips, required this.onOpen});

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
          : '${upcoming.title ?? upcoming.destination} • ${upcoming.days} days',
      trailing: upcoming == null
          ? null
          : TextButton(
              onPressed: () => onOpen(upcoming!),
              child: const Text('Open'),
            ),
      child: upcoming == null
          ? const Text('Start a new plan to see it here.')
          : Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Destructive actions, kept visually and physically apart from everything
/// else on the page so that "Delete account" is never a near-miss for a
/// button someone actually meant to press.
class _DangerZone extends StatelessWidget {
  final VoidCallback onDelete;
  const _DangerZone({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delete account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Permanently removes your account, your saved trips and their '
            'plans, your preferences, and your feedback. This cannot be '
            'undone and nothing can be recovered afterwards.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }
}

/// Asks for the password, then runs the deletion.
///
/// The password is not decoration: Firebase refuses to delete an account on a
/// sign-in older than a few minutes, so re-authentication is required anyway.
/// Requiring it here means it doubles as the confirmation step.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final authViewModel = context.read<AuthViewModel>();
    final tripViewModel = context.read<TripViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Drop the trips snapshot listener first. Left running, it would report
    // permission-denied the moment the account disappears and surface an
    // error for a flow that succeeded. Returns immediately - it does not wait
    // on the cancel, so deletion is never blocked by it.
    tripViewModel.stopListeningToTripHistory();

    var deleted = false;
    try {
      // Bounded so a stalled network call or platform channel surfaces as a
      // readable error instead of a spinner that never stops. The account is
      // either deleted or it is not; a timeout here means "unknown", and the
      // message says to check rather than claiming failure.
      deleted = await authViewModel
          .deleteAccount(_passwordController.text)
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'This is taking too long. Check your connection, then '
            'reopen the app to see whether the account was removed.';
      });
      return;
    }

    if (!mounted) return;

    if (!deleted) {
      setState(() {
        _busy = false;
        _error = authViewModel.errorMessage ?? 'Unable to delete your account.';
      });
      return;
    }

    // Captured above, because AuthGate tears this subtree down as soon as the
    // user goes null. ScaffoldMessenger sits above the navigator, so the
    // message survives the page swap.
    navigator.pop(true);
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account and all its data are gone.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your trips, plans, preferences and feedback will be deleted '
            'permanently. There is no way to get them back.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _passwordController,
            obscureText: _hidePassword,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _delete(),
            decoration: InputDecoration(
              labelText: 'Confirm your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: _hidePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _hidePassword = !_hidePassword),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          onPressed: _busy ? null : _delete,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete forever'),
        ),
      ],
    );
  }
}
