import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthAccountSnapshot {
  const AuthAccountSnapshot({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.hasPasswordProvider,
  });

  final String uid;
  final String? email;
  final String displayName;
  final bool hasPasswordProvider;
}

abstract interface class ProfileAuthService {
  AuthAccountSnapshot? get currentAccount;

  Future<AuthAccountSnapshot?> refreshAndSyncCurrentUserProfile();

  Future<void> updateDisplayName(String displayName);

  Future<void> updateEmail({
    required String email,
    required String currentPassword,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> logout();
}

abstract interface class PasswordRecoveryService {
  Future<void> sendPasswordReset(String email);
}

class AuthService implements ProfileAuthService, PasswordRecoveryService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  AuthAccountSnapshot? get currentAccount {
    final user = currentUser;
    if (user == null) return null;
    return _accountSnapshot(user);
  }

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
    await user.reload();
    final registeredUser = currentUser ?? user;
    await registeredUser.getIdToken(true);
    await _firestore.collection('users').doc(registeredUser.uid).set({
      'uid': registeredUser.uid,
      'email': registeredUser.email ?? normalizedEmail,
      'displayName': registeredUser.displayName ?? normalizedName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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

  @override
  Future<void> sendPasswordReset(String email) {
    final normalizedEmail = email.trim();
    if (!_isValidEmail(normalizedEmail)) {
      throw const FormatException('Enter a valid email address.');
    }
    return _auth.sendPasswordResetEmail(
      email: normalizedEmail,
      actionCodeSettings: _actionCodeSettings,
    );
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) throw StateError('No authenticated user.');
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Enter a display name.');
    }
    await user.updateDisplayName(normalizedName);
    await refreshAndSyncCurrentUserProfile();
  }

  /// Reloads Firebase Auth and mirrors only its current values into Firestore.
  /// A pending, unverified email change is never written to the profile.
  @override
  Future<AuthAccountSnapshot?> refreshAndSyncCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    await user.reload();
    final refreshedUser = currentUser;
    if (refreshedUser == null) return null;

    // Firestore rules inspect the email and verification state in this token.
    await refreshedUser.getIdToken(true);

    final profile = _firestore.collection('users').doc(refreshedUser.uid);
    final existingProfile = await profile.get();
    final existingData = existingProfile.data();
    final currentEmail = refreshedUser.email;
    final needsSync =
        !existingProfile.exists ||
        existingData?['uid'] != refreshedUser.uid ||
        existingData?['displayName'] != (refreshedUser.displayName ?? '') ||
        existingData?['email'] != currentEmail;
    if (!needsSync) return _accountSnapshot(refreshedUser);

    final data = <String, dynamic>{
      'uid': refreshedUser.uid,
      'displayName': refreshedUser.displayName ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': existingData?['createdAt'] ?? FieldValue.serverTimestamp(),
    };
    if (currentEmail != null) data['email'] = currentEmail;
    await profile.set(data);
    return _accountSnapshot(refreshedUser);
  }

  @override
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
    if (newPassword == currentPassword) {
      throw const FormatException(
        'Choose a new password that differs from your current password.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  @override
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
    if (!_hasPasswordProvider(user)) {
      throw StateError(
        'This account uses Google sign-in. Change its email through Google account settings.',
      );
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
    await user.verifyBeforeUpdateEmail(normalizedEmail, _actionCodeSettings);
  }

  bool hasPasswordProvider(User? user) =>
      user != null && _hasPasswordProvider(user);

  AuthAccountSnapshot _accountSnapshot(User user) => AuthAccountSnapshot(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName ?? '',
    hasPasswordProvider: _hasPasswordProvider(user),
  );

  @override
  Future<void> logout() => _auth.signOut();

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  ActionCodeSettings? get _actionCodeSettings {
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) return null;
    const continueUrl = String.fromEnvironment('FIREBASE_AUTH_CONTINUE_URL');
    if (continueUrl.isEmpty) return null;
    return ActionCodeSettings(url: continueUrl, handleCodeInApp: false);
  }

  bool _hasPasswordProvider(User user) =>
      user.providerData.any((provider) => provider.providerId == 'password');
}
