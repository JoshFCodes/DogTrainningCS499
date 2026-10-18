import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void>? _googleInitialization;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> registerWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Do not disclose whether an email address has an account.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  Future<void> sendVerificationEmail() async {
    final user = _requireUser();

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> refreshUser() async {
    try {
      await _requireUser().reload();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-disabled' ||
          error.code == 'user-not-found' ||
          error.code == 'user-token-expired') {
        await signOut();
      }
      rethrow;
    }
  }

  Future<void> _initializeGoogle() async {
    try {
      await (_googleInitialization ??= GoogleSignIn.instance.initialize());
    } catch (_) {
      // Allow another attempt after a failed initialization.
      _googleInitialization = null;
      rethrow;
    }
  }

  Future<OAuthCredential> _googleCredential() async {
    await _initializeGoogle();

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message: 'Google did not return an ID token.',
      );
    }

    return GoogleAuthProvider.credential(idToken: idToken);
  }

  GoogleAuthProvider _googleProvider() {
    return GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
  }

  AppleAuthProvider _appleProvider() {
    return AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(_googleProvider());
    } else {
      await _auth.signInWithCredential(await _googleCredential());
    }
  }

  Future<void> signInWithApple() async {
    final provider = _appleProvider();

    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  Future<void> linkGoogle() async {
    final user = _requireUser();

    if (kIsWeb) {
      await user.linkWithPopup(_googleProvider());
    } else {
      await user.linkWithCredential(await _googleCredential());
    }

    await user.reload();
  }

  Future<void> linkApple() async {
    final user = _requireUser();
    final provider = _appleProvider();

    if (kIsWeb) {
      await user.linkWithPopup(provider);
    } else {
      await user.linkWithProvider(provider);
    }

    await user.reload();
  }

  Future<void> signOut() async {
    // Clear Firebase first so a provider cleanup failure cannot keep
    // the user signed into the application.
    await _auth.signOut();

    if (!kIsWeb && _googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign-out already succeeded.
      }
    }
  }

  User _requireUser() {
    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    return user;
  }
}

/// Shared messages for authentication and Firestore failures.
String accountErrorMessage(Object error) {
  if (error is GoogleSignInException) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return 'Google sign-in was canceled.';
    }

    return 'Google sign-in could not finish. Check the platform '
        'configuration if this keeps happening.';
  }

  //Literally everything I can think of
  if (error is FirebaseException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The account details could not be verified.';
      case 'email-already-in-use':
        return 'An account already uses this email. Sign in instead.';
      case 'weak-password':
      case 'password-does-not-meet-requirements':
        return 'Choose a password that meets the project password policy.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before trying again.';
      case 'network-request-failed':
      case 'unavailable':
        return 'Check your connection and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method has not been enabled in Firebase.';
      case 'account-exists-with-different-credential':
        return 'Sign in using your existing method, then link this '
            'provider from Account & pets.';
      case 'credential-already-in-use':
        return 'That provider account belongs to another user. '
            'Sign out to use that account.';
      case 'provider-already-linked':
        return 'This sign-in method is already linked.';
      case 'requires-recent-login':
        return 'Sign out and sign in again, then repeat this action.';
      case 'popup-closed-by-user':
      case 'canceled-popup-request':
      case 'web-context-cancelled':
        return 'Sign-in was canceled.';
      case 'popup-blocked':
        return 'Allow sign-in pop-ups in your browser.';
      case 'unauthorized-domain':
        return 'Add this website to Firebase Authentications '
            'authorized domains.';
      case 'permission-denied':
        return 'Access was denied. Check your session and the '
            'Firestore rules.';
      default:
        return 'The action could not finish (${error.code}).';
    }
  }

  return 'The action could not finish. Please try again.';
}
