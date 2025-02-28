import 'package:flutter/material.dart';
import '../models/user_account.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  UserAccount? _user;
  bool _isInitialized = false;

  UserAccount? get user => _user;
  bool get isLoggedIn => _user != null;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _userService.initialize();
    _user = _authService.currentUser;
    
    if (_user != null) {
      // Load user data from Firestore
      final userData = await _userService.loadUser(_user!.id);
      if (userData != null) {
        _user = userData;
        // Ensure UserService has the current user
        await _userService.saveUser(_user!);
        notifyListeners();
      }
    }

    // Listen to auth state changes
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        final userData = await _userService.loadUser(user.id);
        _user = userData ?? user;
      } else {
        _user = null;
      }
      notifyListeners();
    });

    _isInitialized = true;
  }

  // Sign in
  Future<void> signIn(String email, String password) async {
    try {
      _user = await _authService.signInWithEmailAndPassword(email, password);
      if (user == null) throw Exception('Sign in failed');
      await _userService.loadUser(_user!.id);
      notifyListeners();
    } catch (e) {
      // Rethrow to let UI handle the error
      rethrow;
    }
  }

  // Register
  Future<void> register(String email, String password, String username) async {
    _user = await _authService.registerWithEmailAndPassword(
      email,
      password,
      username,
    );
    if (_user == null) throw Exception('Registration failed');
    await _userService.saveUser(_user!);
    notifyListeners();
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    await _userService.clearCache();
    _user = null;
    notifyListeners();
  }

  // Update game stats
  Future<void> updateGameStats({
    bool? isWin,
    bool? isDraw,
    int? movesToWin,
    required bool isOnline,
  }) async {
    if (_user == null) return;

    // Update local state
    _user!.updateStats(
      isWin: isWin,
      isDraw: isDraw,
      movesToWin: movesToWin,
      isOnline: isOnline,
    );
    notifyListeners();

    // Update Firestore
    await _userService.updateGameStats(
      userId: _user!.id,
      isWin: isWin,
      isDraw: isDraw,
      movesToWin: movesToWin,
      isOnline: isOnline,
    );
  }

  // Update username
  Future<void> updateUsername(String newUsername) async {
    if (_user == null) return;
    
    await _authService.updateUsername(newUsername);
    _user = _user!.copyWith(username: newUsername);
    await _userService.saveUser(_user!);
    notifyListeners();
  }

  // Update email and password
  Future<void> updateEmailAndPassword(String newEmail, String? newPassword) async {
    if (_user == null) return;
    
    final user = _authService.currentUser;
    if (user == null) throw Exception('Not signed in');

    if (newEmail != user.email) {
      await _authService.updateEmail(newEmail);
      _user = _user!.copyWith(email: newEmail);
      await _userService.saveUser(_user!);
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      await _authService.updatePassword(newPassword);
    }

    notifyListeners();
  }
}
