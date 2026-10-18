import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';
import '../data/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.signedInBuilder});

  final WidgetBuilder signedInBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authChanges;

  @override
  void initState() {
    super.initState();
    _authChanges = AuthService.instance.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Unable to read your session. Restart the app.'),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return const LoginScreen();
        }

        return _SignedInSession(
          key: ValueKey(user.uid),
          user: user,
          homeBuilder: widget.signedInBuilder,
        );
      },
    );
  }
}

class _SignedInSession extends StatefulWidget {
  const _SignedInSession({
    super.key,
    required this.user,
    required this.homeBuilder,
  });

  final User user;
  final WidgetBuilder homeBuilder;

  @override
  State<_SignedInSession> createState() => _SignedInSessionState();
}

class _SignedInSessionState extends State<_SignedInSession> {
  late Future<void> _initialization;
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _signOutError;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() {
    return ProfileRepository(widget.user.uid).ensureProfile(widget.user);
  }

  Future<void> _signOut() async {
    try {
      await AuthService.instance.signOut();
    } catch (error) {
      if (mounted) {
        setState(() => _signOutError = accountErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'You are signed in, but your profile could '
                        'not be loaded.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        accountErrorMessage(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _initialization = _initialize();
                          });
                        },
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: _signOut,
                        child: const Text('Sign out'),
                      ),
                      if (_signOutError != null) Text(_signOutError!),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return NavigatorPopHandler<Object?>(
          onPopWithResult: (result) {
            _navigatorKey.currentState!.pop(result);
          },
          child: Navigator(
            key: _navigatorKey,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: widget.homeBuilder),
          ),
        );
      },
    );
  }
}
