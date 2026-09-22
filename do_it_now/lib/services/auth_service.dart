import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedName = displayName.trim();
    if (!_isValidEmail(normalizedEmail)) {
      throw const FormatException('Enter a valid email address.');
    }
    if (normalizedName.isEmpty) {
      throw const FormatException('Enter a display name.');
    }
    if (password.length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Account creation failed.');

    await user.updateDisplayName(normalizedName);
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': normalizedEmail,
      'displayName': normalizedName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return credential;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim();
    if (!_isValidEmail(normalizedEmail)) {
      throw const FormatException('Enter a valid email address.');
    }
    if (password.isEmpty) throw const FormatException('Enter your password.');
    return _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    }
    return _auth.signInWithProvider(provider);
  }

  Future<void> sendPasswordReset(String email) {
    final normalizedEmail = email.trim();
    if (!_isValidEmail(normalizedEmail)) {
      throw const FormatException('Enter a valid email address.');
    }
    return _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) throw StateError('No authenticated user.');
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Enter a display name.');
    }
    await user.updateDisplayName(normalizedName);
    await _firestore.collection('users').doc(user.uid).set({
      'displayName': normalizedName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.reload();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('A password account is required.');
    }
    if (!user.providerData.any(
      (provider) => provider.providerId == 'password',
    )) {
      throw StateError(
        'This account uses Google sign-in. Set a password through password recovery first.',
      );
    }
    if (newPassword.length < 6) {
      throw const FormatException(
        'New password must be at least 6 characters.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> updateEmail({
    required String email,
    required String currentPassword,
  }) async {
    final user = currentUser;
    final currentEmail = user?.email;
    final normalizedEmail = email.trim();
    if (user == null || currentEmail == null) {
      throw StateError('A password account is required.');
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw const FormatException('Enter a valid email address.');
    }
    if (normalizedEmail == currentEmail) return;
    final credential = EmailAuthProvider.credential(
      email: currentEmail,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(normalizedEmail);
    await _firestore.collection('users').doc(user.uid).set({
      'email': normalizedEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logout() => _auth.signOut();

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}
