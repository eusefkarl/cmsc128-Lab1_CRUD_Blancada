import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_panel.dart';

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
  bool _profileMessageIsError = true;
  bool _passwordMessageIsError = true;

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
      setState(() {
        _profileMessage = 'Enter your current password to change your email.';
        _profileMessageIsError = true;
      });
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
      setState(() {
        _passwordMessage = 'Enter your current password and a new password with 6+ characters.';
        _passwordMessageIsError = true;
      });
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
          _profileMessageIsError = false;
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _profileMessageIsError = true;
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
          _profileMessageIsError = true;
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
          _passwordMessageIsError = false;
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _passwordMessageIsError = true;
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
          _passwordMessageIsError = true;
          _passwordMessage = error.message;
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _passwordMessageIsError = true;
          _passwordMessage = error.message;
        });
      }
    }
  }

  Widget _feedback(String message, {required bool isError}) {
    final color = isError ? AppColors.highPriority : AppColors.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.raisedSurface,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 600 ? 16 : 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusPanel(
                  padding: 20,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF352554),
                        foregroundColor: AppColors.primaryText,
                        child: Text(
                          (_name.text.isEmpty ? '?' : _name.text[0])
                              .toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const StatusEyebrow('Player profile'),
                            const SizedBox(height: 4),
                            Text(
                              _name.text.isEmpty ? 'Profile' : _name.text,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontFamily: 'Exo 2',
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              FirebaseAuth.instance.currentUser?.email ?? '',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StatusPanel(
                  padding: 20,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Account details',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _name,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a display name.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                          ),
                          validator: (value) =>
                              value == null ||
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value.trim())
                              ? 'Enter a valid email address.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _currentPassword,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Current password',
                            helperText: 'Required when changing your email or password.',
                          ),
                        ),
                        if (_profileMessage != null) ...[
                          const SizedBox(height: 16),
                          _feedback(
                            _profileMessage!,
                            isError: _profileMessageIsError,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (_loading) ...[
                          Semantics(
                            liveRegion: true,
                            label: 'Updating account',
                            child: LinearProgressIndicator(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          onPressed: _loading ? null : _saveName,
                          child: const Text('Save profile'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StatusPanel(
                  padding: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Change password',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newPassword,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          helperText: 'At least 6 characters',
                        ),
                      ),
                      if (_passwordMessage != null) ...[
                        const SizedBox(height: 16),
                        _feedback(
                          _passwordMessage!,
                          isError: _passwordMessageIsError,
                        ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _loading ? null : _changePassword,
                        child: const Text('Change password'),
                      ),
                    ],
                  ),
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
