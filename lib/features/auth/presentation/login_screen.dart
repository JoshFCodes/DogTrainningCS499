import 'package:flutter/material.dart';

import '../data/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _message;

  AuthService get _auth => AuthService.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await action();

      if (mounted && successMessage != null) {
        setState(() => _message = successMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = accountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    _run(() {
      if (_registering) {
        return _auth.registerWithEmail(_email.text, _password.text);
      }

      return _auth.signInWithEmail(_email.text, _password.text);
    });
  }

  void _resetPassword() {
    final error = _validateEmail(_email.text);

    if (error != null) {
      setState(() => _message = error);
      return;
    }

    _run(
      () => _auth.sendPasswordReset(_email.text),
      successMessage:
          'If this address has an eligible account, a reset email '
          'will arrive shortly.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/welcome_logo.png',
                      height: 130,
                      semanticLabel: 'Learning With Lenbo',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Learning With Lenbo',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A little guidance. A happier dog.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password.';
                        }

                        if (_registering && value.length < 6) {
                          return 'Use at least 6 characters.';
                        }

                        return null;
                      },
                    ),
                    if (_registering) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPassword,
                        enabled: !_busy,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        validator: (value) {
                          return value == _password.text
                              ? null
                              : 'Passwords do not match.';
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_registering ? 'Create account' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _registering = !_registering;
                                _message = null;
                                _confirmPassword.clear();
                              });
                            },
                      child: Text(
                        _registering
                            ? 'Already registered? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                    if (!_registering)
                      TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(_auth.signInWithGoogle),
                      child: const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(_auth.signInWithApple),
                      icon: const Icon(Icons.apple),
                      label: const Text('Continue with Apple'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your first Google or Apple sign-in creates '
                      'your account.',
                      textAlign: TextAlign.center,
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_message!, textAlign: TextAlign.center),
                        ),
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
}
