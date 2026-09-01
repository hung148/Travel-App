import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/widgets/auth_error_banner.dart';
import 'package:travel/widgets/auth_layout.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool sent = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.resetPassword(
      emailController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authViewModel.errorMessage!)));
      return;
    }

    setState(() => sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: sent ? 'Check your inbox' : 'Reset your password',
      subtitle: sent
          ? 'We sent a password reset link to ${emailController.text.trim()}.'
          : 'Enter the email connected to your account and we’ll send you a reset link.',
      icon: sent ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
      child: sent ? _successView(context) : _formView(context),
    );
  }

  Widget _formView(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Consumer<AuthViewModel>(
            builder: (context, authViewModel, _) =>
                AuthErrorBanner(message: authViewModel.errorMessage),
          ),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => resetPassword(),
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Enter your email address';
              if (!email.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 22),
          Consumer<AuthViewModel>(
            builder: (context, authViewModel, _) {
              return SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: authViewModel.isLoading ? null : resetPassword,
                  child: authViewModel.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send reset link'),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _successView(BuildContext context) {
    return Column(
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
                  'The link may take a minute to arrive. Check your spam folder too.',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Return to sign in'),
          ),
        ),
      ],
    );
  }
}
