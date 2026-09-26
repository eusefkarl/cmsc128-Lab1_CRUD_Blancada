import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_panel.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_registering) {
        await _auth.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
      } else {
        await _auth.login(email: _email.text, password: _password.text);
      }
    } on FirebaseAuthException catch (error) {
      _setError(_firebaseMessage(error.code, error.message));
    } on FirebaseException catch (error) {
      _setError(_firebaseMessage(error.code, error.message));
    } on FormatException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Something went wrong. Please try again.');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      _setError(_firebaseMessage(error.code, error.message));
    } on FirebaseException catch (error) {
      _setError(_firebaseMessage(error.code, error.message));
    } catch (error) {
      _setError('Google sign-in failed: $error');
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  String _firebaseMessage(String code, String? details) => switch (code) {
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Email or password is incorrect.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Choose a stronger password.',
    'user-disabled' => 'This account has been disabled.',
    'operation-not-allowed' => 'Email/password sign-in is disabled in Firebase. Enable it in Authentication > Sign-in method.',
    'network-request-failed' =>
      'Network request failed. Check your internet connection.',
    'popup-closed-by-user' => 'Google sign-in was cancelled.',
    'account-exists-with-different-credential' =>
      'An account already exists with another sign-in method.',
    'permission-denied' => 'Firebase rejected the profile write. Deploy the updated Firestore rules.',
    _ => 'Firebase error ($code): ${details ?? 'Please try again.'}',
  };

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter your $label.' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: StatusPanel(
                padding: 24,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.bolt,
                          size: 40,
                          color: AppColors.cyan,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(child: StatusEyebrow('System access')),
                      const SizedBox(height: 8),
                      Text(
                        _registering ? 'Create your account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontFamily: 'Exo 2',
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DO IT NOW!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.raisedSurface,
                              border: Border.all(color: AppColors.highPriority),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.highPriority,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_registering) ...[
                        TextFormField(
                          controller: _name,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                          ),
                          validator: (value) =>
                              _required(value, 'display name'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        validator: (value) {
                          if (_required(value, 'email address') != null) {
                            return 'Enter your email address.';
                          }
                          return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value!.trim())
                              ? null
                              : 'Enter a valid email address.';
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        autofillHints: [
                          _registering
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (_required(value, 'password') != null) {
                            return 'Enter your password.';
                          }
                          if (_registering && value!.length < 6) {
                            return 'Use at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                      if (!_registering)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  ),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_registering ? 'Create account' : 'Log in'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Continue with Google'),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _registering = !_registering;
                                _error = null;
                              }),
                        child: Text(
                          _registering
                              ? 'Already have an account? Log in'
                              : 'Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
