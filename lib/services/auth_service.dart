import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// AuthService — now minimal since OTP is handled by backend API.
/// Firebase Auth is kept only for FCM push notification support.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user (for FCM/push notifications only)
  User? get currentUser => _auth.currentUser;

  /// Sign out from Firebase (for FCM cleanup)
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] SignOut error: $e');
    }
  }
}
