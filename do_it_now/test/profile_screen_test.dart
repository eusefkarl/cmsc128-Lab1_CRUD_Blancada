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
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Send verification email'),
          )
          .onPressed,
      isNull,
    );
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

  @override
  AuthAccountSnapshot get currentAccount => account;

  @override
  Future<AuthAccountSnapshot> refreshAndSyncCurrentUserProfile() async =>
      account;

  @override
  Future<void> updateDisplayName(String displayName) async {
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
  Future<void> logout() async {}
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
