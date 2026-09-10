import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/auth_service.dart';
import 'package:travel/service/account_deletion_service.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';

class AuthFake extends Fake implements AuthService {
  final List<String> events;
  AuthFake(this.events);
  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();
  @override
  Future<void> reauthenticateWithPassword(String password) async { events.add('reauth'); }
  @override
  Future<void> deleteAuthAccount() async { events.add('delete-auth'); }
}
class DataFake extends Fake implements AccountDeletionService {
  final List<String> events;
  final bool fail;
  DataFake(this.events, this.fail);
  @override
  Future<void> deleteDataForUser(String uid) async {
    events.add('delete-data'); if (fail) throw StateError('network failure');
  }
}
void main() {
  for (final fail in [false, true]) {
    test('authentication is deleted only after data deletion succeeds (failure=$fail)', () async {
      final events = <String>[];
      final model = AuthViewModel(AuthFake(events), DataFake(events, fail));
      model.user = AppUser(uid: 'u', name: 'Test', email: 'test@example.com');
      expect(await model.deleteAccount('password'), !fail);
      expect(events, fail ? ['reauth', 'delete-data'] : ['reauth', 'delete-data', 'delete-auth']);
      if (fail) expect(model.user, isNotNull);
      model.dispose();
    });
  }
}
