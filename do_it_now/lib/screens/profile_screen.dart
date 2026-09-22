import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _profileMessage;
  String? _passwordMessage;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _name.text = user?.displayName ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (_email.text.trim() != currentEmail && _currentPassword.text.isEmpty) {
      setState(
        () => _profileMessage =
            'Enter your current password to change your email.',
      );
      return;
    }
    await _runProfile(() async {
      await _auth.updateDisplayName(_name.text);
      await _auth.updateEmail(
        email: _email.text,
        currentPassword: _currentPassword.text,
      );
    }, 'Profile updated. Check your inbox to confirm a new email.');
  }

  Future<void> _changePassword() async {
    if (_currentPassword.text.isEmpty || _newPassword.text.length < 6) {
      setState(
        () => _passwordMessage = 'Enter your current password and a new password with 6+ characters.',
      );
      return;
    }
    await _runPassword(
      () => _auth.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      ),
      'Password changed.',
    );
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _runProfile(
    Future<void> Function() action,
    String success,
  ) async {
    setState(() {
      _loading = true;
      _profileMessage = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _loading = false;
          _profileMessage = success;
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _profileMessage =
              error.code == 'wrong-password' ||
                  error.code == 'invalid-credential'
              ? 'Current password is incorrect.'
              : 'Could not update your account.';
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _profileMessage = error.message;
        });
      }
    }
  }

  Future<void> _runPassword(
    Future<void> Function() action,
    String success,
  ) async {
    setState(() {
      _loading = true;
      _passwordMessage = null;
    });
    try {
      await action();
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) {
        setState(() {
          _loading = false;
          _passwordMessage = success;
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _passwordMessage =
              error.code == 'wrong-password' ||
                  error.code == 'invalid-credential'
              ? 'Current password is incorrect.'
              : 'Could not change your password.';
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _passwordMessage = error.message;
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _passwordMessage = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 34,
                  child: Text(
                    (_name.text.isEmpty ? '?' : _name.text[0]).toUpperCase(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFBFE6F5)),
                ),
                const SizedBox(height: 24),
                if (_profileMessage != null) ...[
                  Text(_profileMessage!),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a display name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (value) =>
                      value == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _saveName,
                  child: const Text('Save profile'),
                ),
                const SizedBox(height: 28),
                Text(
                  'Change password',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: const Color(0xFFF0F6F8)),
                ),
                const SizedBox(height: 12),
                if (_passwordMessage != null) ...[
                  Text(
                    _passwordMessage!,
                    style: const TextStyle(color: Color(0xFFFF5272)),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _currentPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loading ? null : _changePassword,
                  child: const Text('Change password'),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
