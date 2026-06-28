import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../services/firestore_order_service.dart';

/// Manages real Firebase Auth sign-in/sign-up for drivers and keeps
/// [kDriverId]/[kDriverName] in sync with the authenticated session.
class DriverAuthProvider extends ChangeNotifier {
  DriverAuthProvider() {
    if (kUseFirebase) {
      _authSub = fb.FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
    }
  }

  StreamSubscription<fb.User?>? _authSub;
  DriverProfile? _profile;
  bool _initializing = true;
  String? blockedMessage;
  BankDetails _bankDetails = const BankDetails();

  DriverProfile? get profile => _profile;
  bool get isLoggedIn => _profile != null;
  bool get initializing => _initializing;
  BankDetails get bankDetails => _bankDetails;

  Future<void> _loadBankDetails(String uid) async {
    try {
      _bankDetails = await FirestoreOrderService.instance.fetchBankDetails(uid);
      notifyListeners();
    } catch (e) {
      debugPrint('[DriverAuth] loadBankDetails failed: $e');
    }
  }

  /// Returns null on success, an error message on failure.
  Future<String?> updateBankDetails(BankDetails details) async {
    final profile = _profile;
    if (profile == null) return 'Not signed in.';
    try {
      await FirestoreOrderService.instance.updateBankDetails(profile.id, details);
      _bankDetails = details;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[DriverAuth] updateBankDetails failed: $e');
      return 'Could not save bank details — check your connection and try again.';
    }
  }

  /// Returns null on success, an error message on failure.
  Future<String?> updateProfileFields({String? name, String? phone, String? campus}) async {
    final profile = _profile;
    if (profile == null) return 'Not signed in.';
    try {
      await FirestoreOrderService.instance
          .updateDriverProfile(profile.id, name: name, phone: phone, campus: campus);
      _profile = profile.copyWith(name: name, phone: phone, campus: campus);
      if (name != null) kDriverName = name;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[DriverAuth] updateProfileFields failed: $e');
      return 'Could not save — check your connection and try again.';
    }
  }

  Future<void> _onAuthStateChanged(fb.User? user) async {
    if (user == null) {
      _profile = null;
      _bankDetails = const BankDetails();
      kDriverId = '';
      kDriverName = 'Driver';
      _initializing = false;
      notifyListeners();
      return;
    }
    try {
      var profile = await FirestoreOrderService.instance.fetchDriverProfile(user.uid);
      if (profile == null) {
        // First sign-in via a provider that doesn't go through our signUp()
        // flow (e.g. Google) — bootstrap a profile from the provider's data.
        profile = DriverProfile(
          id: user.uid,
          name: user.displayName ?? 'Driver',
          email: user.email ?? '',
          phone: user.phoneNumber ?? '',
          studentId: '',
        );
        await FirestoreOrderService.instance.createDriverProfile(profile);
      }
      if (profile.isSuspended) {
        blockedMessage = 'Your driver account has been suspended. Contact support if you think this is a mistake.';
        await fb.FirebaseAuth.instance.signOut();
        _initializing = false;
        notifyListeners();
        return;
      }
      _profile = profile;
      kDriverId = profile.id;
      kDriverName = profile.name;
      unawaited(_loadBankDetails(profile.id));
    } catch (e) {
      debugPrint('[DriverAuth] profile fetch failed: $e');
    }
    _initializing = false;
    notifyListeners();
  }

  /// Returns null on success, an error message on failure.
  Future<String?> signIn(String email, String password) async {
    try {
      await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on fb.FirebaseAuthException {
      return 'Invalid email or password.';
    }
  }

  /// Creates a new driver account + Firestore profile. Returns null on
  /// success, an error message on failure.
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String studentId,
  }) async {
    try {
      fb.UserCredential cred;
      try {
        cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        // Same email already has an account in this Firebase project — likely
        // from the user app, since one person can be both. Sign in to the
        // existing account instead of failing, so the login is shared.
        cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }

      final existing = await FirestoreOrderService.instance.fetchDriverProfile(cred.user!.uid);
      final profile = existing ??
          DriverProfile(
            id: cred.user!.uid,
            name: name,
            email: email.toLowerCase().trim(),
            phone: phone,
            studentId: studentId,
          );
      if (existing == null) {
        await FirestoreOrderService.instance.createDriverProfile(profile);
      }
      _profile = profile;
      kDriverId = profile.id;
      kDriverName = profile.name;
      unawaited(_loadBankDetails(profile.id));
      notifyListeners();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      // Newer Firebase Auth versions report a wrong password on the
      // cross-app sign-in fallback as 'invalid-credential' rather than the
      // older 'wrong-password' code — catch both so the raw Firebase
      // message never reaches the user.
      return (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? 'An account with this email already exists with a different password. Use that password, or sign in instead.'
          : e.message ?? 'Could not create your account. Please try again.';
    }
  }

  /// Returns null on success (including user-cancelled — not an error worth
  /// surfacing), or an error message on genuine failure.
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user backed out of the picker
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await fb.FirebaseAuth.instance.signInWithCredential(credential);
      return null;
    } catch (e) {
      debugPrint('[DriverAuth] Google sign-in failed: $e');
      return 'Google sign-in failed. Please try again.';
    }
  }

  /// Returns null on success (including user-cancelled — not an error worth
  /// surfacing), or an error message on genuine failure.
  Future<String?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final cred = await fb.FirebaseAuth.instance.signInWithCredential(oauthCredential);
      // Apple only returns the name on the FIRST authorization ever, and
      // Firebase doesn't capture it automatically — persist it ourselves.
      final fullName = [appleCredential.givenName, appleCredential.familyName]
          .where((p) => p != null && p.isNotEmpty)
          .join(' ');
      if (fullName.isNotEmpty && cred.user != null && (cred.user!.displayName ?? '').isEmpty) {
        await cred.user!.updateDisplayName(fullName);
      }
      return null;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('[DriverAuth] Apple sign-in failed: $e');
      return 'Apple sign-in failed. Please try again.';
    } catch (e) {
      debugPrint('[DriverAuth] Apple sign-in failed: $e');
      return 'Apple sign-in failed. Please try again.';
    }
  }

  Future<void> signOut() async {
    await fb.FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
