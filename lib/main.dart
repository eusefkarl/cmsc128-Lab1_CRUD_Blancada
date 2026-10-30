import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/collaborative_workspace.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on StateError catch (error) {
    runApp(StartupConfigurationError(message: error.message.toString()));
    return;
  }
  await Firebase.initializeApp(options: options);
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator('127.0.0.1', 5001);
  }
  runApp(const MyApp());
}

class StartupConfigurationError extends StatelessWidget {
  const StartupConfigurationError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DO IT NOW! — setup required',
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firebase setup required',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SelectableText(message),
                const SizedBox(height: 16),
                const SelectableText(
                  'Restart with: flutter run -d chrome '
                  '--dart-define-from-file=.env',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => AuthNavigationScope(
    sessionIds: FirebaseAuth.instance.authStateChanges().map(
      (user) => user?.uid,
    ),
    initialSessionId: FirebaseAuth.instance.currentUser?.uid,
    home: const AuthGate(),
  );
}

class AuthNavigationScope extends StatelessWidget {
  const AuthNavigationScope({
    super.key,
    required this.sessionIds,
    required this.home,
    this.initialSessionId,
  });

  final Stream<String?> sessionIds;
  final String? initialSessionId;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: sessionIds,
      builder: (context, snapshot) => MaterialApp(
        // Recreate the navigator when the account changes. Pushed account
        // routes cannot outlive sign-out, even when it happens elsewhere.
        key: ValueKey(
          snapshot.connectionState == ConnectionState.waiting
              ? initialSessionId
              : snapshot.data,
        ),
        title: 'DO IT NOW!',
        theme: AppTheme.dark,
        home: home,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      return user == null
          ? const AuthScreen()
          : _ProfileSyncGate(
              key: ValueKey(user.uid),
              child: const CollaborativeWorkspace(),
            );
    },
  );
}

class _ProfileSyncGate extends StatefulWidget {
  const _ProfileSyncGate({super.key, required this.child});

  final Widget child;

  @override
  State<_ProfileSyncGate> createState() => _ProfileSyncGateState();
}

class _ProfileSyncGateState extends State<_ProfileSyncGate>
    with WidgetsBindingObserver {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncProfile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_syncProfile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncProfile() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await AuthService().refreshAndSyncCurrentUserProfile();
    } on FirebaseAuthException catch (error) {
      debugPrint('Could not refresh the signed-in account: ${error.code}');
    } on FirebaseException catch (error) {
      debugPrint('Could not sync the signed-in profile: ${error.code}');
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
