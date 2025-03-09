import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_account.dart';
import '../models/user_level.dart';
import '../logic/computer_player.dart';
import '../services/auth/auth_service.dart';
import '../services/user/user_service.dart';
import '../models/utils/logger.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserAccount? _user;
  bool _isInitialized = false;
  bool _isOnline = false;

  UserAccount? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isOnline => _isOnline;

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
        // Set user as online
        await _setUserOnlineStatus(true);
        // Ensure UserService has the current user
        await _userService.saveUser(_user!);
        notifyListeners();
      }
    }

    // // Listen to auth state changes
    // _authService.authStateChanges.listen((user) async {
    //   if (user != null) {
    //     final userData = await _userService.loadUser(user.id);
    //     _user = userData ?? user;
    //   } else {
    //     _user = null;
    //   }
    //   notifyListeners();
    // });

    _isInitialized = true;
  }

  // Sign in
  Future<void> signIn(String email, String password) async {
    try {
      _user = await _authService.signInWithEmailAndPassword(email, password);
      if (user == null) throw Exception('Sign in failed');
      await _userService.loadUser(_user!.id);
      await _setUserOnlineStatus(true);
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
    if (_user != null) {
      await _setUserOnlineStatus(false);
    }
    await _authService.signOut();
    await _userService.clearCache();
    _user = null;
    notifyListeners();
  }

  Future<void> updateGameStats({
  bool? isWin,
  bool? isDraw,
  int? movesToWin,
  required bool isOnline,
  bool isFriendlyMatch = false,
  bool isHellMode = false,
  GameDifficulty difficulty = GameDifficulty.easy,
}) async {
  if (_user == null) return;

  // Update local state for game statistics
  _user!.updateStats(
    isWin: isWin,
    isDraw: isDraw,
    movesToWin: movesToWin,
    isOnline: isOnline,
  );

  // Only award XP for online games or computer games (not 2-player local games or friendly matches)
  if (isOnline || !isFriendlyMatch) {
    // Calculate XP to award based on game outcome
    int xpToAward = UserLevel.calculateGameXp(
      isWin: isWin ?? false,
      isDraw: isDraw ?? false,
      movesToWin: movesToWin,
      level: _user!.userLevel.level,
      isHellMode: isHellMode, // Pass hell mode status for double XP
      difficulty: difficulty, // Pass difficulty level for XP calculation
    );

    // Add XP to user
    _user = _user!.addXp(xpToAward);
    final difficultyName = difficulty.toString().split('.').last;
    final hellModeText = isHellMode ? ' (2x Hell Mode bonus)' : '';
    logger.i('User gained $xpToAward XP - $difficultyName difficulty$hellModeText. New total: ${_user!.totalXp}, Level: ${_user!.userLevel.level}');
  } else {
    logger.i('No XP awarded for friendly/2-player match');
  }

  notifyListeners();

  // Update Firestore
  await _userService.updateGameStatsAndXp(
    userId: _user!.id,
    isWin: isWin,
    isDraw: isDraw,
    movesToWin: movesToWin,
    isOnline: isOnline,
    xpToAdd: isOnline || !isFriendlyMatch ? _calculateXpToAward(isWin, isDraw, movesToWin, isHellMode: isHellMode, difficulty: difficulty) : 0,
    totalXp: _user!.totalXp,
    userLevel: _user!.userLevel,
  );
}
    
  
  // Helper method to calculate XP
  int _calculateXpToAward(bool? isWin, bool? isDraw, int? movesToWin, {bool isHellMode = false, GameDifficulty difficulty = GameDifficulty.easy}) {
    return UserLevel.calculateGameXp(
      isWin: isWin ?? false,
      isDraw: isDraw ?? false,
      movesToWin: movesToWin,
      level: _user!.userLevel.level,
      isHellMode: isHellMode,
      difficulty: difficulty,
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
  
  // Set user online status
  Future<void> _setUserOnlineStatus(bool status) async {
    if (_user == null) return;
    
    try {
      _isOnline = status;
      _user = _user!.copyWith(isOnline: status);
      
      // Update Firestore
      await _firestore.collection('users').doc(_user!.id).update({
        'isOnline': status,
        'lastOnline': FieldValue.serverTimestamp(),
      });
      
      notifyListeners();
    } catch (e) {
      logger.e('Error updating online status: $e');
    }
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

  Future<void> refreshUserData({bool forceServerRefresh = false}) async {
  if (_user == null) {
    logger.w('Cannot refresh user data: User is null');
    return;
  }

  try {
    logger.i('Refreshing user data for ${_user!.id} (forceServerRefresh: $forceServerRefresh)');

    // Force a fresh data fetch from Firestore
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(_user!.id);
    
    // Always use Source.server when forceServerRefresh is true to ensure we get the latest data
    final userDoc = await userDocRef.get(
      GetOptions(source: forceServerRefresh ? Source.server : Source.serverAndCache),
    );

    if (userDoc.exists && userDoc.data() != null) {
      // Log the raw data for debugging
      final rawData = userDoc.data()!;
      logger.d('Raw user data from Firestore: ${rawData.toString()}');
      
      // Create user from document data
      final userData = UserAccount.fromJson({...rawData, 'id': userDoc.id});

      // Update the user data in memory
      _user = userData;
      notifyListeners();
      return;
    } else {
      logger.w('User document not found or empty during refresh');
    }

    // Fallback to user service if direct fetch fails
    logger.i('Falling back to user service for refresh');
    final userData = await _userService.loadUser(_user!.id);
    if (userData != null) {
      // Update the user data in memory
      _user = userData;

      notifyListeners();
    } else {
      logger.w('Failed to refresh user data via both Firestore and user service');
    }
  } catch (e, stackTrace) {
    logger.e('Error refreshing user data: $e');
    logger.e('Stack trace: $stackTrace');
  }
}
  // Add XP to user and update in Firestore
  Future<void> addXp(int xpAmount) async {
    if (_user == null) return;

    // Add XP locally
    _user = _user!.addXp(xpAmount);
    notifyListeners();

    // Update Firestore
    await _userService.updateGameStatsAndXp(
      userId: _user!.id,
      xpToAdd: xpAmount,
      totalXp: _user!.totalXp,
      userLevel: _user!.userLevel,
      isOnline: _isOnline,
    );

    logger.i('Added $xpAmount XP. New total: ${_user!.totalXp}, Level: ${_user!.userLevel.level}');
  }
}
