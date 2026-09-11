import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/views/auth/forgot_password.dart';
import 'package:travel/widgets/auth_error_banner.dart';
import 'package:travel/widgets/auth_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool hidePassword = true;

  @override
  void initState() {
    super.initState();
    // Clear any error left over from another auth screen. Done after the
    // first frame because clearError() notifies listeners, which cannot
    // happen while this widget is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthViewModel>().clearError();
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final authViewModel = context.read<AuthViewModel>();

    // Pressing Enter in the password field calls this directly, around the
    // button's disabled state, so the in-flight check belongs here too.
    if (authViewModel.isLoading) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    // A failure lands in AuthViewModel.errorMessage, which AuthErrorBanner
    // renders above the form. No SnackBar here, so the same message is not
    // shown to the user twice.
    // Disconnect the browser text-input session while authentication runs.
    FocusScope.of(context).unfocus();
    final succeeded = await authViewModel.login(
      emailController.text.trim(),
      passwordController.text,
    );
    if (!mounted || succeeded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _passwordFocus.requestFocus();
    });
  }

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordPage(initialEmail: emailController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to continue planning your next trip.',
      icon: Icons.login_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Consumer<AuthViewModel>(
              builder: (context, authViewModel, _) =>
                  AuthErrorBanner(message: authViewModel.errorMessage),
            ),
            TextFormField(
              controller: emailController,
              focusNode: _emailFocus,
              onTap: () => _emailFocus.requestFocus(),
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
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
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              focusNode: _passwordFocus,
              onTap: () => _passwordFocus.requestFocus(),
              obscureText: hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => login(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Enter your password';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: openForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 14),
            Consumer<AuthViewModel>(
              builder: (context, authViewModel, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: authViewModel.isLoading ? null : login,
                    child: authViewModel.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign in'),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'New to Travel App?',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
