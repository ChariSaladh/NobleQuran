import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication state
enum AuthStatus { initial, authenticated, unauthenticated, guest }

/// User model
class User {
  final String email;
  final String name;
  final DateTime createdAt;

  User({required this.email, required this.name, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    email: json['email'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
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

  AuthProvider() {
    _checkAuthStatus();
  }

  /// Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);

      if (userData != null) {
        _user = User.fromJson(json.decode(userData));
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
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
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

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

      // Check if email already exists (simulated)
      final prefs = await SharedPreferences.getInstance();
      final existingUser = prefs.getString(_userKey);

      if (existingUser != null) {
        final existingUserData = User.fromJson(json.decode(existingUser));
        if (existingUserData.email.toLowerCase() == email.toLowerCase()) {
          _error = 'An account with this email already exists';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Create user (in a real app, this would be saved to backend)
      _user = User(name: name, email: email);

      // Save to local storage
      await prefs.setString(_userKey, json.encode(_user!.toJson()));
      await prefs.setString(
        _authTokenKey,
        'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      );

      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
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
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

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

      // Check credentials (simulated - in real app this would validate against backend)
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);

      if (userData != null) {
        final user = User.fromJson(json.decode(userData));

        // For demo purposes, accept any password that matches the email format
        // In production, this would validate against a backend
        if (user.email.toLowerCase() == email.toLowerCase()) {
          _user = user;
          await prefs.setString(
            _authTokenKey,
            'mock_token_${DateTime.now().millisecondsSinceEpoch}',
          );

          _status = AuthStatus.authenticated;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      // For demo: allow sign in with any valid email format
      if (RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _user = User(name: email.split('@').first, email: email);
        await prefs.setString(_userKey, json.encode(_user!.toJson()));
        await prefs.setString(
          _authTokenKey,
          'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        );

        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Invalid email or password';
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
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

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

      // In a real app, this would send a reset email via backend
      // For demo, we'll just simulate success

      _isLoading = false;
      notifyListeners();
      return true;
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
}
