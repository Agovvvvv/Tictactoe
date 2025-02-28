import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_account.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late SharedPreferences _prefs;
  UserAccount? _currentUser;

  // Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCachedUser();
  }

  // Load user from cache
  void _loadCachedUser() {
    final userData = _prefs.getString('user_data');
    if (userData != null) {
      try {
        final Map<String, dynamic> userMap = json.decode(userData);
        // Validate required fields
        if (userMap['id'] == null || userMap['username'] == null || userMap['email'] == null) {
          throw FormatException('Missing required fields');
        }
        _currentUser = UserAccount.fromJson(userMap);
      } catch (e) {
        print('Error loading cached user: $e');
        // Clear invalid cache
        _prefs.remove('user_data');
        _currentUser = null;
      }
    }
  }

  // Get current user
  UserAccount? get currentUser => _currentUser;

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return querySnapshot.docs.isEmpty;
  }

  // Save user data to both Firestore and local cache
  Future<void> saveUser(UserAccount user, {bool checkUsernameUniqueness = true}) async {
    try {
      final userData = user.toJson();
      // Validate data before saving
      if (userData['id'] == null || userData['username'] == null || userData['email'] == null) {
        throw FormatException('Missing required fields');
      }

      // Check if this is an existing user
      final existingDoc = await _firestore.collection('users').doc(user.id).get();
      final isNewUser = !existingDoc.exists;

      // For existing users, only check username uniqueness if the username has changed
      if (!isNewUser && checkUsernameUniqueness) {
        final existingData = existingDoc.data();
        if (existingData != null && existingData['username'] != userData['username']) {
          if (!await isUsernameAvailable(userData['username'])) {
            throw Exception('Username is already taken');
          }
        }
      } else if (isNewUser && checkUsernameUniqueness) {
        // For new users, always check username uniqueness
        if (!await isUsernameAvailable(userData['username'])) {
          throw Exception('Username is already taken');
        }
      }

      // Save to Firestore
      await _firestore.collection('users').doc(user.id).set(userData);

      // Save to local cache
      final userJson = json.encode(userData);
      await _prefs.setString('user_data', userJson);
      _currentUser = user;
    } catch (e) {
      print('Error saving user: $e');
      throw e; // Re-throw to handle in the calling code
    }
  }

  // Load user data from Firestore
  Future<UserAccount?> loadUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final user = UserAccount.fromJson(doc.data()!);
      // Save to cache without checking username uniqueness since this is an existing user
      await saveUser(user, checkUsernameUniqueness: false);
      return user;
    } catch (e) {
      print('Error loading user: $e');
      return null;
    }
  }

  // Update game statistics
  Future<void> updateGameStats({
    required String userId,
    bool? isWin,
    bool? isDraw,
    int? movesToWin,
    required bool isOnline,
  }) async {
    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final user = UserAccount.fromJson(userData);

      // Update stats
      user.updateStats(
        isWin: isWin,
        isDraw: isDraw,
        movesToWin: movesToWin,
        isOnline: isOnline,
      );

      // Save updated user data
      await _firestore.collection('users').doc(userId).update(user.toJson());

      // Update cache if this is the current user
      if (_currentUser?.id == userId) {
        _currentUser = user;
        await _prefs.setString('user_data', json.encode(user.toJson()));
      }
    } catch (e) {
      print('Error updating game stats: $e');
      rethrow;
    }
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return {};

    return {
      'gamesPlayed': doc.data()?['gamesPlayed'] ?? 0,
      'gamesWon': doc.data()?['gamesWon'] ?? 0,
      'gamesLost': doc.data()?['gamesLost'] ?? 0,
      'gamesDraw': doc.data()?['gamesDraw'] ?? 0,
      'winRate': doc.data()?['winRate'] ?? 0.0,
      'currentStreak': doc.data()?['currentWinStreak'] ?? 0,
      'bestStreak': doc.data()?['highestWinStreak'] ?? 0,
    };
  }

  // Clear local cache
  Future<void> clearCache() async {
    await _prefs.remove('user_data');
    _currentUser = null;
  }
}
