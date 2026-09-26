import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_panel.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.auth});

  final PasswordRecoveryService? auth;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  late final PasswordRecoveryService _auth;
  bool _loading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? AuthService();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await _auth.sendPasswordReset(_email.text);
      if (mounted) {
        setState(() {
          _loading = false;
          _success = true;
          _message = 'If an account exists for that email, a password-reset link has been sent.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _success = error.code == 'user-not-found';
          _message = switch (error.code) {
            'user-not-found' => 'If an account exists for that email, a password-reset link has been sent.',
            'too-many-requests' =>
              'Too many attempts. Wait a while, then try again.',
            'network-request-failed' =>
              'The request could not reach the server. Check your connection.',
            'operation-not-allowed' =>
              'Password recovery is not enabled for this Firebase project.',
            _ => 'Could not send the reset email. Please try again.',
          };
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: Center(
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
                  const StatusEyebrow('System access'),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter your account email and we will send a reset link.',
                  ),
                  const SizedBox(height: 24),
                  if (_message != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.raisedSurface,
                          border: Border.all(
                            color: _success
                                ? AppColors.success
                                : AppColors.highPriority,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _success
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _success
                                  ? AppColors.success
                                  : AppColors.highPriority,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_message!)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _send,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send reset link'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
