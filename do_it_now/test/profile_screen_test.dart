import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:do_it_now/screens/profile_screen.dart';
import 'package:do_it_now/screens/forgot_password_screen.dart';
import 'package:do_it_now/services/auth_service.dart';

void main() {
  testWidgets('display name saves separately and email change stays pending', (
    tester,
  ) async {
    final service = FakeProfileAuthService();
    await _pumpProfile(tester, service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Updated name',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save display name'));
    await tester.pumpAndSettle();

    expect(find.text('Display name updated.'), findsOneWidget);
    expect(service.account.displayName, 'Updated name');

    final proposedEmail = 'updated@example.test';
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New email address'),
      proposedEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Current password').first,
      'current-password',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send verification email'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Verification requested for $proposedEmail. Check that inbox and its spam/junk folder. Your current email remains active until you verify it.',
      ),
      findsOneWidget,
    );
    expect(service.pendingEmail, proposedEmail);
    expect(service.account.email, 'player@example.test');
  });

  testWidgets(
    'password change requires matching confirmation and clears on success',
    (tester) async {
      final service = FakeProfileAuthService();
      await _pumpProfile(tester, service);

      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Confirm new password'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'current-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'new-password-123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'different-password',
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(service.passwordChanges, 0);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'new-password-123',
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password changed. Your new password is active.'),
        findsOneWidget,
      );
      expect(service.lastNewPassword, 'new-password-123');
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Confirm new password'),
            )
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('Google-only accounts get provider-specific guidance', (
    tester,
  ) async {
    final service = FakeProfileAuthService(hasPasswordProvider: false);
    await _pumpProfile(tester, service);

    expect(
      find.text(
        'This account uses Google sign-in. Manage its password through Google.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'New password'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'New email address'),
      findsNothing,
    );
    expect(find.text('Current email address'), findsOneWidget);
    expect(find.text('Send verification email'), findsNothing);
  });

  testWidgets('back asks before discarding a changed display name', (
    tester,
  ) async {
    final service = FakeProfileAuthService();
    await _pumpProfileRoute(tester, service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Unsent name',
    );
    await tester.pump();
    expect(
      tester
          .widget<PopScope>(
            find.byWidgetPredicate((widget) => widget is PopScope),
          )
          .canPop,
      isFalse,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Unsent name'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open profile'), findsOneWidget);
  });

  testWidgets('logout asks before losing unsaved password entries', (
    tester,
  ) async {
    final service = FakeProfileAuthService();
    await _pumpProfileRoute(tester, service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'unsaved-password',
    );
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(service.logoutCount, 0);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(service.logoutCount, 0);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(service.logoutCount, 1);
  });

  testWidgets('saving display name shows progress and blocks resubmission', (
    tester,
  ) async {
    final service = FakeProfileAuthService()
      ..saveCompletion = Completer<void>();
    await _pumpProfile(tester, service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Next name',
    );
    await tester.tap(find.text('Save display name'));
    await tester.pump();
    expect(find.text('Saving display name…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save display name'),
          )
          .onPressed,
      isNull,
    );
    service.saveCompletion!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Display name updated.'), findsOneWidget);
  });

  testWidgets('requested email verification is not an unsaved draft', (
    tester,
  ) async {
    final service = FakeProfileAuthService();
    await _pumpProfileRoute(tester, service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New email address'),
      'pending@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Current password').first,
      'current-password',
    );
    await tester.tap(find.text('Send verification email'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsNothing);
    expect(find.text('Open profile'), findsOneWidget);
  });

  testWidgets('an unauthenticated profile shows no account data', (
    tester,
  ) async {
    final service = FakeProfileAuthService()..signedOut = true;
    await _pumpProfile(tester, service);
    expect(find.text('Sign in to view your profile.'), findsOneWidget);
    expect(find.text('player@example.test'), findsNothing);
    expect(find.text('Account details'), findsNothing);
  });

  testWidgets(
    'password recovery does not reveal whether an email is registered',
    (tester) async {
      final service = FakePasswordRecoveryService(userNotFound: true);
      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordScreen(auth: service)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'unknown@example.test',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If an account exists for that email, a password-reset link has been sent.',
        ),
        findsOneWidget,
      );
      expect(find.text('No account was found for that email.'), findsNothing);
      expect(service.requestedEmail, 'unknown@example.test');
    },
  );
}

Future<void> _pumpProfile(
  WidgetTester tester,
  FakeProfileAuthService service,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: ProfileScreen(auth: service)));
  await tester.pumpAndSettle();
}

Future<void> _pumpProfileRoute(
  WidgetTester tester,
  FakeProfileAuthService service,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(auth: service),
              ),
            ),
            child: const Text('Open profile'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open profile'));
  await tester.pumpAndSettle();
}

class FakeProfileAuthService implements ProfileAuthService {
  FakeProfileAuthService({bool hasPasswordProvider = true})
    : account = AuthAccountSnapshot(
        uid: 'test-user',
        email: 'player@example.test',
        displayName: 'Player',
        hasPasswordProvider: hasPasswordProvider,
      );

  AuthAccountSnapshot account;
  String? pendingEmail;
  String? lastNewPassword;
  int passwordChanges = 0;
  int logoutCount = 0;
  bool signedOut = false;
  Completer<void>? saveCompletion;

  @override
  AuthAccountSnapshot? get currentAccount => signedOut ? null : account;

  @override
  Future<AuthAccountSnapshot?> refreshAndSyncCurrentUserProfile() async =>
      signedOut ? null : account;

  @override
  Future<void> updateDisplayName(String displayName) async {
    await saveCompletion?.future;
    account = AuthAccountSnapshot(
      uid: account.uid,
      email: account.email,
      displayName: displayName,
      hasPasswordProvider: account.hasPasswordProvider,
    );
  }

  @override
  Future<void> updateEmail({
    required String email,
    required String currentPassword,
  }) async {
    pendingEmail = email;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChanges += 1;
    lastNewPassword = newPassword;
  }

  @override
  Future<void> logout() async {
    logoutCount += 1;
  }
}

class FakePasswordRecoveryService implements PasswordRecoveryService {
  FakePasswordRecoveryService({this.userNotFound = false});

  final bool userNotFound;
  String? requestedEmail;

  @override
  Future<void> sendPasswordReset(String email) async {
    requestedEmail = email;
    if (userNotFound) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
  }
}
