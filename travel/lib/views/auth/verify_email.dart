import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/widgets/auth_layout.dart';

/// Shown to a signed-in user whose email address is not confirmed yet.
///
/// Firebase writes `emailVerified` into the ID token the client is holding, so
/// clicking the link in the inbox does not reach the running app on its own.
/// Nothing here happens by magic: the screen polls
/// [AuthViewModel.refreshVerificationStatus] while it is open, and offers a
/// button for the same check.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  /// How often the screen asks Firebase whether the link has been clicked.
  static const _pollInterval = Duration(seconds: 4);

  /// Firebase rate-limits verification mail, so the resend button is held
  /// shut for a while after each press rather than letting the user collect
  /// a `too-many-requests` error.
  static const _resendCooldown = Duration(seconds: 60);

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _secondsUntilResend = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Asks Firebase for fresh user data.
  ///
  /// When it comes back verified, AuthGate swaps this screen out on the next
  /// rebuild - there is nothing to navigate to from here. [silent] keeps the
  /// background poll from nagging the user every four seconds.
  Future<void> _check({required bool silent}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) setState(() {});

    final authViewModel = context.read<AuthViewModel>();
    var verified = false;
    try {
      // Bounded so a stalled call cannot leave the button spinning forever.
      // A timeout only means "not verified yet" - the next poll retries.
      verified = await authViewModel.refreshVerificationStatus().timeout(
        const Duration(seconds: 10),
      );
    } catch (error) {
      debugPrint('Verification check failed: $error');
    } finally {
      // In a finally on purpose: left true on an error path, this would
      // disable the continue button for the life of the screen.
      _checking = false;
    }

    if (!mounted) return;
    if (!silent) setState(() {});

    if (!verified && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Not verified yet. Open the link in the email, then try again.',
          ),
        ),
      );
    }
  }

  Future<void> _resend() async {
    final sent = await context.read<AuthViewModel>().resendEmailVerification();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Verification email sent again.'
              : 'Could not send it right now. Wait a minute and try again.',
        ),
      ),
    );

    if (sent) _startCooldown();
  }

  void _startCooldown() {
    setState(() => _secondsUntilResend = _resendCooldown.inSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsUntilResend--);
      if (_secondsUntilResend <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthViewModel>().user?.email ?? 'your email';
    final canResend = _secondsUntilResend <= 0;

    return AuthLayout(
      title: 'Verify your email',
      subtitle:
          'We sent a link to $email. Open it, and this screen will continue on '
          'its own.',
      icon: Icons.mark_email_unread_outlined,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No email? Check your spam folder. The link is valid for a '
                    'few days.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _checking ? null : () => _check(silent: false),
              child: _checking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("I've verified — continue"),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: canResend ? _resend : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              canResend
                  ? 'Resend the email'
                  : 'Resend in ${_secondsUntilResend}s',
            ),
          ),
          const Divider(height: 32),
          // The escape hatch. Without this, anyone who mistyped their address
          // at signup would be stuck on this screen with no way out.
          TextButton.icon(
            onPressed: () => context.read<AuthViewModel>().logout(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out and use a different email'),
          ),
        ],
      ),
    );
  }
}
