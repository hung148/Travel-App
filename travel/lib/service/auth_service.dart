import 'package:firebase_auth/firebase_auth.dart';

Future<void> register(String email, String password) async {
  await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
}

Future<void> login(String email, String password) async {
  await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
}

Future<void> logout() async {
  await FirebaseAuth.instance.signOut();
}

