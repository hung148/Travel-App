import 'dart:convert';

import 'package:http/http.dart' as http;

/// Direct client for the two Firebase Identity Toolkit endpoints this app
/// needs for account deletion.
///
/// WHY THIS EXISTS
///
/// On Windows and Linux, firebase_auth answers reauthenticateWithCredential
/// from a non-platform thread. Flutter drops that reply ("sent a message from
/// native to Flutter on a non-platform thread"), so the Dart Future never
/// completes: no error, no result, just a call that hangs forever. user
/// .delete() goes through the same machinery.
///
/// These are the REST endpoints the Firebase SDKs themselves call, so this is
/// not a workaround around Firebase - it is the same operation, reached
/// without the plugin. The API key is the public Firebase Web API key already
/// compiled into the app; it identifies the project and is not a secret.
class AuthRestClient {
  final http.Client _client;

  AuthRestClient({http.Client? client}) : _client = client ?? http.Client();

  static const _base = 'https://identitytoolkit.googleapis.com/v1';
  static const _timeout = Duration(seconds: 20);

  /// Verifies [email] and [password] and returns a fresh ID token.
  ///
  /// This is the re-authentication step: a wrong password fails here, before
  /// anything has been deleted.
  Future<String> signInForIdToken({
    required String apiKey,
    required String email,
    required String password,
  }) async {
    final response = await _post('accounts:signInWithPassword', apiKey, {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });

    final token = response['idToken'];
    if (token is! String || token.isEmpty) {
      throw Exception('Could not confirm your password. Please try again.');
    }
    return token;
  }

  /// Deletes the account the [idToken] belongs to.
  Future<void> deleteAccount({
    required String apiKey,
    required String idToken,
  }) async {
    await _post('accounts:delete', apiKey, {'idToken': idToken});
  }

  Future<Map<String, dynamic>> _post(
    String path,
    String apiKey,
    Map<String, dynamic> body,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_base/$path?key=$apiKey'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (error) {
      throw Exception(
        'Could not reach Firebase. Check your connection and try again.',
      );
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode == 200) return data;

    final error = data['error'];
    final code = error is Map && error['message'] is String
        ? error['message'] as String
        : '';
    throw Exception(_messageForCode(code));
  }

  /// The REST API reports its own error strings, which do not match the
  /// FirebaseAuthException codes used elsewhere in the app.
  static String _messageForCode(String code) {
    // Codes can carry a suffix, e.g. "TOO_MANY_ATTEMPTS_TRY_LATER : ...".
    final normalized = code.split(':').first.trim();
    switch (normalized) {
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'MISSING_PASSWORD':
        return 'Incorrect password.';
      case 'EMAIL_NOT_FOUND':
        return 'No account found for this email.';
      case 'USER_DISABLED':
        return 'This account has been disabled. Contact support for help.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'INVALID_ID_TOKEN':
      case 'CREDENTIAL_TOO_OLD_LOGIN_AGAIN':
        return 'For your security, sign in again before deleting your account.';
      case '':
        return 'Authentication failed. Please try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
