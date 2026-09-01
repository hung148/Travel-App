import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/auth_service.dart';

void main() {
  group('AuthService error messages', () {
    test('uses friendly messages for common authentication failures', () {
      expect(
        AuthService.authErrorMessage('invalid-credential'),
        'Invalid email or password.',
      );
      expect(
        AuthService.authErrorMessage('email-already-in-use'),
        'This email is already in use.',
      );
      expect(
        AuthService.authErrorMessage('too-many-requests'),
        'Too many attempts. Wait a few minutes and try again.',
      );
      expect(
        AuthService.authErrorMessage('network-request-failed'),
        'Unable to connect. Check your internet connection and try again.',
      );
    });

    test('uses Firebase fallback text for an unknown error code', () {
      expect(
        AuthService.authErrorMessage(
          'unknown-code',
          fallback: 'Specific Firebase error',
        ),
        'Specific Firebase error',
      );
    });

    test('uses a safe default when no fallback is available', () {
      expect(
        AuthService.authErrorMessage('unknown-code'),
        'Authentication failed. Please try again.',
      );
    });
  });
}
