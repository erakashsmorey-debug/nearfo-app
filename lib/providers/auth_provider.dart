import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../main.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isNewUser = false;
  String? _devOtp; // For development testing only
  bool _sessionExpired = false;

  // Firebase Phone Auth state
  String? _verificationId;
  int? _resendToken;
  fb.FirebaseAuth get _firebaseAuth => fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '87261108393-s8epfmevb5odfogpgg37nf44ltjo3947.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null && ApiService.isLoggedIn;
  bool get isNewUser => _isNewUser;
  bool get needsProfileSetup => _isNewUser || (_user != null && _user!.name.isEmpty);
  String? get devOtp => _devOtp; // Expose dev OTP for testing
  bool get sessionExpired => _sessionExpired;
  String? get verificationId => _verificationId;

  /// Initialize — check stored token & load user
  Future<void> init() async {
    try {
      await ApiService.loadToken();

      // Wire up session expiry callback
      ApiService.onSessionExpired = _handleSessionExpired;

      if (ApiService.isLoggedIn) {
        await _fetchMe();
      }
    } catch (e) {
      debugPrint('[Auth] Init error: $e');
    }
  }

  /// Handle 401 from API — try refresh token before logging out
  Future<void> _handleSessionExpired() async {
    if (_sessionExpired) return; // Prevent multiple triggers

    // Try to refresh the access token first
    final refreshed = await ApiService.tryRefreshToken();
    if (refreshed) {
      debugPrint('[Auth] Access token refreshed silently — session alive');
      return; // Token refreshed, don't logout
    }

    // Refresh failed — force logout
    debugPrint('[Auth] Refresh token failed — logging out');
    _sessionExpired = true;
    _user = null;
    await ApiService.clearToken();
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] notifyListeners after dispose: $e');
    }
  }

  /// Step 1: Send OTP via Firebase Phone Auth (FREE SMS via Firebase)
  Future<bool> sendOTP(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    _devOtp = null;
    _verificationId = null;
    notifyListeners();

    final completer = Completer<bool>();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,

        // Called when Firebase auto-verifies (instant verification on some Android devices)
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          debugPrint('[Auth] Auto-verification completed');
          // Auto-sign in with Firebase
          try {
            final userCredential = await _firebaseAuth.signInWithCredential(credential);
            if (userCredential.user == null) {
              debugPrint('[Auth] Auto-verify: user is null');
              if (!completer.isCompleted) completer.complete(false);
              return;
            }
            final idToken = await userCredential.user!.getIdToken();
            if (idToken != null) {
              final success = await _verifyWithBackend(idToken, phoneNumber);
              if (!completer.isCompleted) completer.complete(success);
            } else {
              debugPrint('[Auth] Auto-verify: idToken is null');
              if (!completer.isCompleted) completer.complete(false);
            }
          } catch (e) {
            debugPrint('[Auth] Auto-verify sign-in error: $e');
            if (!completer.isCompleted) completer.complete(false);
          }
        },

        // Called when SMS code is sent to the phone
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[Auth] OTP code sent to $phoneNumber');
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        },

        // Called when verification fails
        verificationFailed: (fb.FirebaseAuthException e) {
          debugPrint('[Auth] Verification failed: ${e.code} - ${e.message}');
          _isLoading = false;
          if (e.code == 'too-many-requests') {
            _error = 'Too many OTP requests. Please try after some time.';
          } else if (e.code == 'invalid-phone-number') {
            _error = 'Invalid phone number. Please check and try again.';
          } else if (e.code == 'quota-exceeded') {
            _error = 'SMS quota exceeded. Please try later.';
          } else {
            _error = e.message ?? 'Failed to send OTP. Please try again.';
          }
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
        },

        // Called when code auto-retrieval times out (fires AFTER codeSent)
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[Auth] Auto-retrieval timeout');
          _verificationId = verificationId;
          // Safety: complete if somehow codeSent didn't fire
          if (!completer.isCompleted) {
            _isLoading = false;
            notifyListeners();
            completer.complete(true);
          }
        },
      );
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to send OTP. Check your connection.';
      notifyListeners();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  /// Step 2: Verify OTP entered by user via Firebase
  Future<bool> verifyOTP(String otp, String phoneNumber) async {
    if (_verificationId == null) {
      _error = 'Verification session expired. Please resend OTP.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create credential from OTP
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Sign in with Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) {
        _isLoading = false;
        _error = 'Authentication failed. Please try again.';
        notifyListeners();
        return false;
      }

      // Verify with our backend
      return await _verifyWithBackend(idToken, phoneNumber);
    } on fb.FirebaseAuthException catch (e) {
      _isLoading = false;
      if (e.code == 'invalid-verification-code') {
        _error = 'Invalid OTP. Please check and try again.';
      } else if (e.code == 'session-expired') {
        _error = 'OTP expired. Please resend.';
      } else {
        _error = e.message ?? 'Verification failed. Please try again.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Verification failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Google Sign-In with retry logic and better error handling
  Future<bool> signInWithGoogle({int retryCount = 0}) async {
    const maxRetries = 2;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Disconnect any stale session before signing in fresh
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) {
        _isLoading = false;
        _error = 'Google authentication failed. Please try again.';
        notifyListeners();
        return false;
      }

      // Verify with backend using Google email
      final email = googleUser.email;
      return await _verifyGoogleWithBackend(idToken, email, googleUser.displayName, googleUser.photoUrl);
    } catch (e, stackTrace) {
      debugPrint('[Auth] Google sign-in error: $e');
      debugPrint('[Auth] Stack trace: $stackTrace');

      final errStr = e.toString().toLowerCase();
      final isNetworkError = errStr.contains('network_error') ||
          errStr.contains('apiexception: 7') ||
          errStr.contains('unexpected end of stream') ||
          errStr.contains('socketexception') ||
          errStr.contains('connection refused');

      // Auto-retry for network errors
      if (isNetworkError && retryCount < maxRetries) {
        debugPrint('[Auth] Network error, retrying (${retryCount + 1}/$maxRetries)...');
        await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
        return signInWithGoogle(retryCount: retryCount + 1);
      }

      _isLoading = false;
      if (isNetworkError) {
        _error = 'Network error. Please check your internet connection and try again.';
      } else if (errStr.contains('sign_in_canceled') || errStr.contains('sign_in_cancelled')) {
        _error = null; // User cancelled, no error to show
        notifyListeners();
        return false;
      } else if (errStr.contains('apiexception: 10')) {
        _error = 'App configuration error. Please contact support.';
      } else {
        _error = 'Google sign-in failed. Please try again.';
      }
      notifyListeners();
      return false;
    }
  }

  /// Verify Google Firebase token with backend
  Future<bool> _verifyGoogleWithBackend(String idToken, String email, String? displayName, String? photoUrl) async {
    try {
      final res = await ApiService.verifyFirebaseToken(
        idToken: idToken,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      if (res.isSuccess && res.data != null) {
        _user = res.data;
        _isNewUser = res.isNewUser;
        _isLoading = false;
        _sessionExpired = false;
        PushNotificationService.initialize(navKey: NearfoApp.navigatorKey);
        notifyListeners();
        return true;
      }

      _error = res.errorMessage ?? 'Login failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Server error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Verify Firebase ID token with our backend — creates/finds user
  Future<bool> _verifyWithBackend(String idToken, String phoneNumber) async {
    try {
      final res = await ApiService.verifyFirebaseToken(
        idToken: idToken,
        phone: phoneNumber,
      );

      if (res.isSuccess && res.data != null) {
        _user = res.data;
        _isNewUser = res.isNewUser;
        _isLoading = false;
        _devOtp = null;
        _verificationId = null;
        _sessionExpired = false;
        PushNotificationService.initialize(navKey: NearfoApp.navigatorKey);
        notifyListeners();
        return true;
      }

      _error = res.errorMessage ?? 'Login failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Server error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Step 3: Setup profile (new users)
  Future<bool> setupProfile({
    required String name,
    required String handle,
    String? bio,
    String? avatarUrl,
    required double latitude,
    required double longitude,
    required String city,
    required String state,
    DateTime? dateOfBirth,
    bool showDobOnProfile = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.setupProfile(
        name: name,
        handle: handle,
        bio: bio,
        avatarUrl: avatarUrl,
        latitude: latitude,
        longitude: longitude,
        city: city,
        state: state,
        dateOfBirth: dateOfBirth,
        showDobOnProfile: showDobOnProfile,
      );

      if (res.isSuccess && res.data != null) {
        _user = res.data;
        _isNewUser = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = res.errorMessage ?? 'Profile setup failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Setup failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Refresh user data
  Future<void> _fetchMe() async {
    try {
      final res = await ApiService.getMe();
      if (res.isSuccess && res.data != null) {
        _user = res.data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Auth] Fetch me error: $e');
    }
  }

  /// Update profile fields (feedPreference, profileVisibility, notificationsEnabled, etc.)
  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.updateProfile(fields);

      _isLoading = false;
      if (res.isSuccess && res.data != null) {
        _user = res.data;
        notifyListeners();
        return true;
      }

      _error = res.errorMessage ?? 'Update failed';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Update failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Update location
  Future<void> updateLocation(double lat, double lng) async {
    try {
      final res = await ApiService.updateLocation(latitude: lat, longitude: lng);
      if (res.isSuccess && res.data != null) {
        _user = res.data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Auth] Location update failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await PushNotificationService.unregister();
    } catch (e) {
      debugPrint('[Auth] Push unregister failed: $e');
    }
    // Revoke refresh token on backend before clearing locally
    try {
      await ApiService.logout();
    } catch (e) {
      debugPrint('[Auth] Backend logout failed: $e');
    }
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[Auth] Google signout failed: $e');
    }
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('[Auth] Firebase signout failed: $e');
    }
    await ApiService.clearToken();
    // NOTE: Do NOT remove 'permissions_screen_shown' on logout.
    // Permissions are device-level — once granted, they stay granted.
    // Re-asking on every re-login is a bad UX.
    _user = null;
    _isNewUser = false;
    _devOtp = null;
    _verificationId = null;
    _resendToken = null;
    _sessionExpired = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
