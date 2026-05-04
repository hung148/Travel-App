import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/trip/trip.dart';
import '../../models/preference/preferences.dart';
import '../widgets/trip_history_widget.dart';
 
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
 
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
 
class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
 
  // TODO: Replace with actual ViewModel/Provider data
  final AppUser _mockUser = AppUser(
    uid: 'u001',
    name: 'Alex Rivera',
    email: 'alex.rivera@email.com',
    profileImage: null,
  );
 
  final Preference _mockPref = Preference(
    id: 'p001',
    ownerId: 'u001',
    experienceType: ['Mix'],
    activityLevel: 'Moderate',
    spendingStyle: 'Normal',
    interests: ['Coffee', 'Attractions'],
  );
 
  final List<Trip> _mockTrips = [
    Trip(
      id: 't1',
      ownerId: 'u001',
      destination: 'Đà Nẵng, Vietnam',
      budget: 800,
      days: 5,
      status: 'completed',
      startDate: DateTime(2025, 3, 10),
      endDate: DateTime(2025, 3, 15),
      rating: 4,
    ),
    Trip(
      id: 't2',
      ownerId: 'u001',
      destination: 'Bangkok, Thailand',
      budget: 1200,
      days: 7,
      status: 'upcoming',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 8),
    ),
    Trip(
      id: 't3',
      ownerId: 'u001',
      destination: 'Kyoto, Japan',
      budget: 2000,
      days: 6,
      status: 'completed',
      startDate: DateTime(2024, 11, 5),
      endDate: DateTime(2024, 11, 11),
      rating: 5,
    ),
  ];
 
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }
 
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildStatsRow(),
                    const SizedBox(height: 28),
                    _buildPreferencesSection(),
                    const SizedBox(height: 28),
                    _buildTripHistorySection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildAddTripFAB(),
    );
  }
 
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A2E),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF2D2B55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6B8CFF).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF34C98B).withValues(alpha: 0.08),
                ),
              ),
            ),
            // Profile info
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B8CFF), Color(0xFF34C98B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B8CFF).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _mockUser.name.isNotEmpty
                            ? _mockUser.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Playfair Display',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mockUser.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Playfair Display',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _mockUser.email,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit preferences button
                  GestureDetector(
                    onTap: _onEditPreferences,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded,
              color: Colors.white70, size: 20),
          onPressed: _onLogout,
        ),
      ],
    );
  }
 
  Widget _buildStatsRow() {
    final completed =
        _mockTrips.where((t) => t.status == 'completed').length;
    final upcoming =
        _mockTrips.where((t) => t.status == 'upcoming').length;
    final totalSpent = _mockTrips
        .where((t) => t.status == 'completed')
        .fold<double>(0, (sum, t) => sum + t.budget);
 
    return Row(
      children: [
        _StatCard(
            label: 'Trips Done', value: '$completed', icon: '✈️'),
        const SizedBox(width: 12),
        _StatCard(
            label: 'Upcoming', value: '$upcoming', icon: '🗓'),
        const SizedBox(width: 12),
        _StatCard(
            label: 'Total Spent',
            value: '\$${totalSpent.toStringAsFixed(0)}',
            icon: '💰'),
      ],
    );
  }
 
  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Your Travel Style',
          onAction: _onEditPreferences,
          actionLabel: 'Edit',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PrefChip(label: _mockPref.experienceType.isNotEmpty ? _mockPref.experienceType[0] : 'Mix', emoji: '🎯'),
            _PrefChip(label: _mockPref.activityLevel, emoji: '🚶'),
            _PrefChip(label: _mockPref.spendingStyle, emoji: '💵'),
            ..._mockPref.interests
                .map((i) => _PrefChip(label: i, emoji: '☕')),
          ],
        ),
      ],
    );
  }
 
  Widget _buildTripHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Trip History',
          onAction: null,
          actionLabel: '',
        ),
        const SizedBox(height: 12),
        TripHistoryWidget(
          trips: _mockTrips,
          onTripTap: (trip) {
            // TODO: Navigate to trip detail
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opening ${trip.destination}...')),
            );
          },
        ),
      ],
    );
  }
 
  Widget _buildAddTripFAB() {
    return FloatingActionButton.extended(
      onPressed: _onAddTrip,
      backgroundColor: const Color(0xFF6B8CFF),
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text(
        'New Trip',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }
 
  void _onEditPreferences() {
    // TODO: Navigate to preference_page.dart
  }
 
  void _onAddTrip() {
    // TODO: Navigate to plan_trip_page.dart
  }
 
  void _onLogout() {
    // TODO: Call auth_viewmodel logout
  }
}
 
// ── Supporting widgets ──────────────────────────────────────
 
class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
 
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });
 
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            fontFamily: 'Playfair Display',
          ),
        ),
        if (onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B8CFF),
              ),
            ),
          ),
      ],
    );
  }
}
 
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
 
  const _StatCard(
      {required this.label, required this.value, required this.icon});
 
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8892A4),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
 
class _PrefChip extends StatelessWidget {
  final String label;
  final String emoji;
 
  const _PrefChip({required this.label, required this.emoji});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3D4A6B),
            ),
          ),
        ],
      ),
    );
  }
}
 