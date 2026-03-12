import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication state
enum AuthStatus { initial, authenticated, unauthenticated, guest }

/// User model
class User {
  final String email;
  final String name;
  final String? uid;
  final DateTime createdAt;

  User({required this.email, required this.name, this.uid, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'uid': uid,
    'createdAt': createdAt.toIso8601String(),
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    email: json['email'] as String,
    name: json['name'] as String,
    uid: json['uid'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  /// Create User from Firebase User
  factory User.fromFirebaseUser(firebaseUser) => User(
    email: firebaseUser.email ?? '',
    name:
        firebaseUser.displayName ??
        firebaseUser.email?.split('@').first ??
        'User',
    uid: firebaseUser.uid,
  );
}

/// Provider for managing authentication
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated || _status == AuthStatus.guest;
  bool get isGuest => _status == AuthStatus.guest;

  static const String _userKey = 'user_data';
  static const String _authTokenKey = 'auth_token';

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  AuthProvider() {
    _checkAuthStatus();
  }

  /// Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    try {
      final currentUser = _firebaseAuth.currentUser;

      if (currentUser != null) {
        _user = User.fromFirebaseUser(currentUser);
        _status = AuthStatus.authenticated;
      } else {
        // Check local storage for cached user
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString(_userKey);

        if (userData != null) {
          _user = User.fromJson(json.decode(userData));
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      }
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Sign up with email and password
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate inputs
      if (name.isEmpty) {
        _error = 'Please enter your name';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (email.isEmpty) {
        _error = 'Please enter your email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _error = 'Please enter a valid email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.isEmpty) {
        _error = 'Please enter a password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.length < 6) {
        _error = 'Password must be at least 6 characters';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password != confirmPassword) {
        _error = 'Passwords do not match';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Create user with Firebase Auth
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(name);

      // Get updated user info
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        _user = User.fromFirebaseUser(firebaseUser);

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, json.encode(_user!.toJson()));

        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to create account';
      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate inputs
      if (email.isEmpty) {
        _error = 'Please enter your email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.isEmpty) {
        _error = 'Please enter your password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Sign in with Firebase Auth
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        _user = User.fromFirebaseUser(credential.user!);

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, json.encode(_user!.toJson()));
        await prefs.setString(_authTokenKey, credential.user!.uid);

        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Invalid email or password';
      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send password reset email
  Future<bool> forgotPassword({required String email}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate email
      if (email.isEmpty) {
        _error = 'Please enter your email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _error = 'Please enter a valid email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Send password reset email via Firebase
      await _firebaseAuth.sendPasswordResetEmail(email: email);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);

      // If guest, just go back to unauthenticated
      if (_status == AuthStatus.guest) {
        _status = AuthStatus.unauthenticated;
        _user = null;
      } else {
        // Keep user data for convenience, but clear auth status
        _status = AuthStatus.unauthenticated;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Continue as guest
  void continueAsGuest() {
    _status = AuthStatus.guest;
    _user = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get Firebase error message
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Please enter a valid email';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'An error occurred. Please try again';
    }
  }
}
