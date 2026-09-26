import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/task_home_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DO IT NOW!',
      theme: AppTheme.dark,
      home: const AuthGate(),
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
              child: const TaskHomePage(),
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
