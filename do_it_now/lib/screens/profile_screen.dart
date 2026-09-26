import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_panel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.auth});

  final ProfileAuthService? auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final _nameFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _emailCurrentPassword = TextEditingController();
  final _passwordCurrentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final ProfileAuthService _auth;

  bool _loading = false;
  bool _syncing = false;
  bool _nameEdited = false;
  bool _emailEdited = false;
  String? _nameMessage;
  String? _emailMessage;
  String? _passwordMessage;
  _FeedbackTone _nameTone = _FeedbackTone.error;
  _FeedbackTone _emailTone = _FeedbackTone.error;
  _FeedbackTone _passwordTone = _FeedbackTone.error;

  AuthAccountSnapshot? get _user => _auth.currentAccount;

  bool get _hasPasswordProvider => _user?.hasPasswordProvider ?? false;

  bool get _busy => _loading || _syncing;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? AuthService();
    WidgetsBinding.instance.addObserver(this);
    _name.text = _user?.displayName ?? '';
    _email.text = _user?.email ?? '';
    _refreshAccount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _email.dispose();
    _emailCurrentPassword.dispose();
    _passwordCurrentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _refreshAccount() async {
    if (_loading || _syncing) return;
    final previousEmail = _user?.email;
    setState(() => _syncing = true);
    try {
      final user = await _auth.refreshAndSyncCurrentUserProfile();
      if (user == null || !mounted) return;
      final emailChanged = previousEmail != user.email;
      setState(() {
        if (!_nameEdited) _name.text = user.displayName;
        if (!_emailEdited || emailChanged) {
          _email.text = user.email ?? '';
          _emailEdited = false;
        }
        if (emailChanged) {
          _emailCurrentPassword.clear();
          _passwordCurrentPassword.clear();
          _newPassword.clear();
          _confirmPassword.clear();
          _emailMessage = 'Email address updated after verification.';
          _emailTone = _FeedbackTone.success;
        }
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _emailMessage = _authError(error.code);
          _emailTone = _FeedbackTone.error;
        });
      }
    } on FirebaseException {
      if (mounted) {
        setState(() {
          _emailMessage = 'Your account could not be synchronized. Check your connection and try again.';
          _emailTone = _FeedbackTone.error;
        });
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _saveDisplayName() async {
    if (!(_nameFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _nameMessage = null;
    });
    try {
      await _auth.updateDisplayName(_name.text);
      if (!mounted) return;
      setState(() {
        _nameEdited = false;
        _nameMessage = 'Display name updated.';
        _nameTone = _FeedbackTone.success;
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _nameMessage = _authError(error.code);
          _nameTone = _FeedbackTone.error;
        });
      }
    } on FirebaseException {
      if (mounted) {
        setState(() {
          _nameMessage = 'The display name was updated in your account, but the profile copy could not sync. Reopen this page when connected.';
          _nameTone = _FeedbackTone.warning;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _nameMessage = error.message;
          _nameTone = _FeedbackTone.error;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendEmailVerification() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    final currentEmail = _user?.email;
    final requestedEmail = _email.text.trim();
    if (currentEmail == requestedEmail) {
      setState(() {
        _emailMessage = 'This is already your current email address.';
        _emailTone = _FeedbackTone.info;
      });
      return;
    }
    if (_emailCurrentPassword.text.isEmpty) {
      setState(() {
        _emailMessage = 'Enter your current password to change your email.';
        _emailTone = _FeedbackTone.error;
      });
      return;
    }

    setState(() {
      _loading = true;
      _emailMessage = null;
    });
    try {
      await _auth.updateEmail(
        email: requestedEmail,
        currentPassword: _emailCurrentPassword.text,
      );
      if (!mounted) return;
      setState(() {
        _emailCurrentPassword.clear();
        _emailEdited = true;
        _emailMessage =
            'Verification requested for $requestedEmail. Check that inbox and its spam/junk folder. Your current email remains active until you verify it.';
        _emailTone = _FeedbackTone.info;
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _emailMessage = _authError(error.code);
          _emailTone = _FeedbackTone.error;
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _emailMessage = error.message;
          _emailTone = _FeedbackTone.error;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _emailMessage = error.message;
          _emailTone = _FeedbackTone.error;
        });
      }
    } finally {
      _emailCurrentPassword.clear();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _passwordMessage = null;
    });
    try {
      await _auth.changePassword(
        currentPassword: _passwordCurrentPassword.text,
        newPassword: _newPassword.text,
      );
      _clearPasswordFields();
      if (mounted) {
        setState(() {
          _passwordMessage = 'Password changed. Your new password is active.';
          _passwordTone = _FeedbackTone.success;
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _passwordMessage = _authError(error.code);
          _passwordTone = _FeedbackTone.error;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _passwordMessage = error.message;
          _passwordTone = _FeedbackTone.error;
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _passwordMessage = error.message;
          _passwordTone = _FeedbackTone.info;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) => switch (code) {
    'email-already-in-use' =>
      'That email address is already associated with another account.',
    'wrong-password' ||
    'invalid-credential' => 'The current password is incorrect.',
    'requires-recent-login' =>
      'Please sign out and sign in again before changing this account detail.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' =>
      'Choose a stronger password that meets your account requirements.',
    'too-many-requests' => 'Too many attempts. Wait a while, then try again.',
    'network-request-failed' =>
      'The request could not reach the server. Check your connection.',
    'operation-not-allowed' =>
      'This account operation is not enabled for this Firebase project.',
    _ => 'The request could not be completed. Please try again.',
  };

  Future<void> _logout() async {
    _clearPasswordFields();
    await _auth.logout();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _clearPasswordFields() {
    _emailCurrentPassword.clear();
    _passwordCurrentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
  }

  Widget _feedback(String message, _FeedbackTone tone) {
    final (color, icon) = switch (tone) {
      _FeedbackTone.success => (AppColors.success, Icons.check_circle_outline),
      _FeedbackTone.info => (AppColors.cyan, Icons.info_outline),
      _FeedbackTone.warning => (
        AppColors.mediumPriority,
        Icons.warning_amber_outlined,
      ),
      _FeedbackTone.error => (AppColors.highPriority, Icons.error_outline),
    };
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
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter $label.' : null;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final displayName = user?.displayName ?? _name.text;
    final email = user?.email ?? '';

    return Scaffold(
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
                            (displayName.isEmpty ? '?' : displayName[0])
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
                                displayName.isEmpty ? 'Profile' : displayName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontFamily: 'Exo 2',
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                email,
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
                      key: _nameFormKey,
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
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => _nameEdited = true,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                            ),
                            validator: (value) =>
                                _required(value, 'a display name'),
                          ),
                          if (_nameMessage != null) ...[
                            const SizedBox(height: 16),
                            _feedback(_nameMessage!, _nameTone),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _saveDisplayName,
                            child: const Text('Save display name'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StatusPanel(
                    padding: 20,
                    child: Form(
                      key: _emailFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Email address',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            onChanged: (_) => _emailEdited = true,
                            decoration: const InputDecoration(
                              labelText: 'New email address',
                            ),
                            validator: (value) =>
                                value == null ||
                                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(value.trim())
                                ? 'Enter a valid email address.'
                                : null,
                          ),
                          if (_hasPasswordProvider) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailCurrentPassword,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              decoration: const InputDecoration(
                                labelText: 'Current password',
                                helperText:
                                    'Required to verify an email change.',
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            const Text(
                              'This account uses Google sign-in. Change its email in your Google account settings.',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ],
                          if (_emailMessage != null) ...[
                            const SizedBox(height: 16),
                            _feedback(_emailMessage!, _emailTone),
                          ],
                          if (_syncing) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: _busy || !_hasPasswordProvider
                                ? null
                                : _sendEmailVerification,
                            child: const Text('Send verification email'),
                          ),
                          TextButton.icon(
                            onPressed: _loading ? null : _refreshAccount,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check verification status'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StatusPanel(
                    padding: 20,
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Change password',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          if (!_hasPasswordProvider) ...[
                            const Text(
                              'This account uses Google sign-in. Manage its password through Google.',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _passwordCurrentPassword,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              decoration: const InputDecoration(
                                labelText: 'Current password',
                              ),
                              validator: (value) =>
                                  _required(value, 'your current password'),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newPassword,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'New password',
                                helperText: 'At least 6 characters',
                              ),
                              validator: (value) {
                                final required = _required(
                                  value,
                                  'a new password',
                                );
                                if (required != null) return required;
                                if (value!.length < 6) {
                                  return 'Use at least 6 characters.';
                                }
                                if (value == _passwordCurrentPassword.text) {
                                  return 'Choose a password different from your current one.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPassword,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                              ),
                              validator: (value) => value != _newPassword.text
                                  ? 'The passwords do not match.'
                                  : null,
                            ),
                            if (_passwordMessage != null) ...[
                              const SizedBox(height: 16),
                              _feedback(_passwordMessage!, _passwordTone),
                            ],
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _busy ? null : _changePassword,
                              child: const Text('Change password'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _logout,
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
}

enum _FeedbackTone { success, info, warning, error }
