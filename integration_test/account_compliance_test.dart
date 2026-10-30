import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:do_it_now/firebase_options.dart';
import 'package:do_it_now/screens/profile_screen.dart';
import 'package:do_it_now/services/auth_service.dart';

const _projectId = 'doitnow-c26f9';
const _authEmulator = 'http://127.0.0.1:9099';
const _password = 'Old-password-123';

late FirebaseAuth _auth;
late FirebaseFirestore _firestore;
late AuthService _authService;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _auth = FirebaseAuth.instance;
    await _auth.useAuthEmulator('127.0.0.1', 9099);
    _firestore = FirebaseFirestore.instance;
    _firestore.useFirestoreEmulator('127.0.0.1', 8080);
    _authService = AuthService();
  });

  setUp(() async => _auth.signOut());

  test(
    'profile name is mirrored and unverified email writes are denied',
    () async {
      final email = _uniqueEmail('profile');
      await _createAccount(email);
      final uid = _auth.currentUser!.uid;

      await _authService.updateDisplayName('Persisted name');
      final authUser = _auth.currentUser!;
      await authUser.reload();
      final profile = await _firestore.collection('users').doc(uid).get();

      expect(_auth.currentUser!.displayName, 'Persisted name');
      expect(profile.data()?['displayName'], 'Persisted name');
      expect(profile.data()?['email'], email);
      expect(profile.data()!.keys, isNot(contains('password')));

      await expectLater(
        _firestore.collection('users').doc(uid).update({
          'email':
              'tampered-${DateTime.now().millisecondsSinceEpoch}@example.test',
        }),
        throwsA(isA<FirebaseException>()),
      );
    },
  );

  test('email change remains pending until verified, then syncs', () async {
    final oldEmail = _uniqueEmail('email-old');
    final newEmail = _uniqueEmail('email-new');
    await _createAccount(oldEmail);
    final uid = _auth.currentUser!.uid;

    await _authService.updateEmail(email: newEmail, currentPassword: _password);
    expect(_auth.currentUser!.email, oldEmail);
    expect(
      (await _firestore.collection('users').doc(uid).get()).data()?['email'],
      oldEmail,
    );

    final actionCode = await _waitForActionCode(
      email: newEmail,
      requestType: 'VERIFY_AND_CHANGE_EMAIL',
    );
    await _auth.applyActionCode(actionCode);
    await _auth.currentUser!.reload();
    await _authService.refreshAndSyncCurrentUserProfile();

    expect(_auth.currentUser!.email, newEmail);
    expect(_auth.currentUser!.emailVerified, isTrue);
    expect(
      (await _firestore.collection('users').doc(uid).get()).data()?['email'],
      newEmail,
    );

    await _auth.signOut();
    await expectLater(
      _auth.signInWithEmailAndPassword(email: oldEmail, password: _password),
      throwsA(isA<FirebaseAuthException>()),
    );
    await _auth.signInWithEmailAndPassword(
      email: newEmail,
      password: _password,
    );
  });

  test(
    'email change rejects a duplicate address and a wrong password',
    () async {
      final firstEmail = _uniqueEmail('duplicate-first');
      final reservedEmail = _uniqueEmail('duplicate-reserved');
      await _createAccount(firstEmail);
      await _createAccount(reservedEmail);
      await _auth.signOut();
      await _authService.login(email: firstEmail, password: _password);

      await expectLater(
        _authService.updateEmail(
          email: reservedEmail,
          currentPassword: _password,
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );
      await expectLater(
        _authService.updateEmail(
          email: _uniqueEmail('wrong-password'),
          currentPassword: 'incorrect-password',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(_auth.currentUser!.email, firstEmail);
    },
  );

  test(
    'password changes accept the new password and reject the old one',
    () async {
      final email = _uniqueEmail('change-password');
      await _createAccount(email);
      const newPassword = 'New-password-456';

      await _authService.changePassword(
        currentPassword: _password,
        newPassword: newPassword,
      );
      await _auth.signOut();
      await expectLater(
        _auth.signInWithEmailAndPassword(email: email, password: _password),
        throwsA(isA<FirebaseAuthException>()),
      );
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: newPassword,
      );
    },
  );

  test(
    'password reset action changes the password and consumes its code',
    () async {
      final email = _uniqueEmail('password-reset');
      await _createAccount(email);
      await _authService.sendPasswordReset(email);

      final actionCode = await _waitForActionCode(
        email: email,
        requestType: 'PASSWORD_RESET',
      );
      expect(await _auth.verifyPasswordResetCode(actionCode), email);
      const newPassword = 'Reset-password-789';
      await _auth.confirmPasswordReset(
        code: actionCode,
        newPassword: newPassword,
      );
      await expectLater(
        _auth.verifyPasswordResetCode(actionCode),
        throwsA(isA<FirebaseAuthException>()),
      );

      await _auth.signOut();
      await expectLater(
        _auth.signInWithEmailAndPassword(email: email, password: _password),
        throwsA(isA<FirebaseAuthException>()),
      );
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: newPassword,
      );
    },
  );

  testWidgets('profile UI confirms new password before saving', (tester) async {
    final email = _uniqueEmail('profile-ui');
    await _createAccount(email);
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Updated profile name',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save display name'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    expect(find.text('Display name updated.'), findsOneWidget);
    expect(_auth.currentUser!.displayName, 'Updated profile name');

    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Confirm new password'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      _password,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'New-password-456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'different-password',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Change password'));
    await tester.pumpAndSettle();

    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('profile email action reports that verification is pending', (
    tester,
  ) async {
    final email = _uniqueEmail('profile-email-ui');
    await _createAccount(email);
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );

    final newEmail = _uniqueEmail('profile-email-pending');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New email address'),
      newEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Current password'),
      _password,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send verification email'),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );

    expect(
      find.text(
        'Verification requested for $newEmail. Check that inbox and its spam/junk folder. Your current email remains active until you verify it.',
      ),
      findsOneWidget,
    );
    expect(_auth.currentUser!.email, email);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _createAccount(String email) async {
  await _authService.register(
    email: email,
    password: _password,
    displayName: 'Compliance test user',
  );
}

String _uniqueEmail(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.test';

Future<String> _waitForActionCode({
  required String email,
  required String requestType,
}) async {
  final uri = Uri.parse(
    '$_authEmulator/emulator/v1/projects/$_projectId/oobCodes',
  );
  for (var attempt = 0; attempt < 40; attempt++) {
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('Could not read Auth emulator action codes.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final codes = (payload['oobCodes'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final match = codes.where(
      (item) =>
          (item['email'] == email || item['newEmail'] == email) &&
          item['requestType'] == requestType,
    );
    if (match.isNotEmpty) return match.last['oobCode'] as String;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('No $requestType action code was created for $email.');
}
