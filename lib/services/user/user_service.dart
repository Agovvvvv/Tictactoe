import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_account.dart';
import '../../models/user_level.dart';
import '../../models/utils/logger.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late SharedPreferences _prefs;
  UserAccount? _currentUser;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCachedUser();
  }

  void _loadCachedUser() {
    final userData = _prefs.getString('user_data');
    if (userData != null) {
      try {
        final Map<String, dynamic> userMap = json.decode(userData);
        if (userMap['id'] == null || userMap['username'] == null || userMap['email'] == null) {
          throw FormatException('Missing required fields');
        }
        _currentUser = UserAccount.fromJson(userMap);
      } catch (e) {
        logger.e('Error loading cached user: $e');
        _prefs.remove('user_data');
        _currentUser = null;
      }
    }
  }

  UserAccount? get currentUser => _currentUser;

  Future<bool> isUsernameAvailable(String username) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return querySnapshot.docs.isEmpty;
  }

  Future<void> saveUser(UserAccount user, {bool checkUsernameUniqueness = true}) async {
    try {
      final userData = user.toJson();
      if (userData['id'] == null || userData['username'] == null || userData['email'] == null) {
        throw FormatException('Missing required fields');
      }

      final existingDoc = await _firestore.collection('users').doc(user.id).get();
      final isNewUser = !existingDoc.exists;

      if (!isNewUser && checkUsernameUniqueness) {
        final existingData = existingDoc.data();
        if (existingData != null && existingData['username'] != userData['username']) {
          if (!await isUsernameAvailable(userData['username'])) {
            throw Exception('Username is already taken');
          }
        }
      } else if (isNewUser && checkUsernameUniqueness) {
        if (!await isUsernameAvailable(userData['username'])) {
          throw Exception('Username is already taken');
        }
      }

      await _firestore.collection('users').doc(user.id).set(userData);
      final userJson = json.encode(userData);
      await _prefs.setString('user_data', userJson);
      _currentUser = user;
    } catch (e) {
      logger.e('Error saving user: $e');
      rethrow;
    }
  }

  Future<UserAccount?> loadUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final user = UserAccount.fromJson(doc.data()!);
      await saveUser(user, checkUsernameUniqueness: false);
      return user;
    } catch (e) {
      logger.e('Error loading user: $e');
      return null;
    }
  }

  Future<void> updateGameStatsAndXp({
    required String userId,
    bool? isWin,
    bool? isDraw,
    int? movesToWin,
    required bool isOnline,
    required int xpToAdd,
    required int totalXp,
    required UserLevel userLevel,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final user = UserAccount.fromJson(userData);

      user.updateStats(
        isWin: isWin,
        isDraw: isDraw,
        movesToWin: movesToWin,
        isOnline: isOnline,
      );

      final updatedUser = user.addXp(xpToAdd);

      await _firestore.collection('users').doc(userId).update({
        'vsComputerStats': updatedUser.vsComputerStats.toJson(),
        'onlineStats': updatedUser.onlineStats.toJson(),
        'totalXp': updatedUser.totalXp,
        'userLevel': updatedUser.userLevel.toJson(),
      });

      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
        await _prefs.setString('user_data', json.encode(updatedUser.toJson()));
      }

      logger.i('Updated user XP in Firestore. Added $xpToAdd XP. New total: $totalXp, Level: ${userLevel.level}');
    } catch (e) {
      logger.e('Error updating game stats and XP: $e');
      rethrow;
    }
  }

  Future<void> updateGameStats({
    required String userId,
    bool? isWin,
    bool? isDraw,
    int? movesToWin,
    required bool isOnline,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    final user = UserAccount.fromJson(userData);

    final xpToAdd = UserLevel.calculateGameXp(
      isWin: isWin ?? false,
      isDraw: isDraw ?? false,
      movesToWin: movesToWin,
      level: user.userLevel.level,
    );

    await updateGameStatsAndXp(
      userId: userId,
      isWin: isWin,
      isDraw: isDraw,
      movesToWin: movesToWin,
      isOnline: isOnline,
      xpToAdd: xpToAdd,
      totalXp: user.totalXp + xpToAdd,
      userLevel: UserLevel.fromTotalXp(user.totalXp + xpToAdd),
    );
  }

  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return {};

    final data = doc.data()!;
    final onlineStats = GameStats.fromJson(data['onlineStats'] as Map<String, dynamic>);
    return {
      'gamesPlayed': onlineStats.gamesPlayed,
      'gamesWon': onlineStats.gamesWon,
      'gamesLost': onlineStats.gamesLost,
      'gamesDraw': onlineStats.gamesDraw,
      'winRate': onlineStats.winRate,
      'currentStreak': onlineStats.currentWinStreak,
      'bestStreak': onlineStats.highestWinStreak,
    };
  }

  Future<void> clearCache() async {
    await _prefs.remove('user_data');
    _currentUser = null;
  }
}