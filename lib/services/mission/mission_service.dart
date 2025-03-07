import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/mission.dart';
import '../../models/utils/logger.dart';
import '../../logic/computer_player.dart';

class MissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get all active missions for a user
  Stream<List<Mission>> getUserMissions(String userId) {
    final now = DateTime.now();
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('missions')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Mission.fromJson(doc.data(), doc.id))
              .toList();
        });
  }
  
  // Get missions by type (daily or weekly)
  Stream<List<Mission>> getMissionsByType(String userId, MissionType type) {
    final now = DateTime.now();
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('missions')
        .where('type', isEqualTo: type.toString().split('.').last)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Mission.fromJson(doc.data(), doc.id))
              .toList();
        });
  }
  
  // Get missions by category (normal or hell)
  Stream<List<Mission>> getMissionsByCategory(String userId, MissionCategory category) {
    final now = DateTime.now();
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('missions')
        .where('category', isEqualTo: category.toString().split('.').last)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Mission.fromJson(doc.data(), doc.id))
              .toList();
        });
  }
  
  // Update mission progress
  Future<void> updateMissionProgress(String userId, String missionKey, int increment) async {
    try {
      // Get all active missions with the given key
      final missionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('missions')
          .where('missionKey', isEqualTo: missionKey)
          .where('completed', isEqualTo: false)
          .get();
      
      // Update each matching mission
      for (var doc in missionsQuery.docs) {
        final mission = Mission.fromJson(doc.data(), doc.id);
        
        // Skip if already completed
        if (mission.completed) continue;
        
        // Calculate new count
        final newCount = mission.currentCount + increment;
        final completed = newCount >= mission.targetCount;
        
        // Update the mission
        await doc.reference.update({
          'currentCount': newCount,
          'completed': completed,
        });
        
        logger.i('Updated mission progress: ${mission.title}, count: $newCount/$mission.targetCount, completed: $completed');
      }
    } catch (e) {
      logger.e('Error updating mission progress: $e');
    }
  }
  
  // Complete a mission and claim reward
  Future<int> completeMission(String userId, String missionId) async {
    try {
      // Get the mission
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('missions')
          .doc(missionId);
      
      final missionDoc = await docRef.get();
      if (!missionDoc.exists) {
        logger.e('Mission not found: $missionId');
        return 0;
      }
      
      final mission = Mission.fromJson(missionDoc.data()!, missionId);
      
      // Check if mission is already completed but not claimed
      if (mission.completed) {
        // Mark as claimed by removing the mission
        await docRef.delete();
        
        logger.i('Mission completed and reward claimed: ${mission.title}, XP: ${mission.xpReward}');
        return mission.xpReward;
      }
      
      return 0;
    } catch (e) {
      logger.e('Error completing mission: $e');
      return 0;
    }
  }
  
  // Generate new missions for a user
  Future<void> generateMissions(String userId) async {
    try {
      final now = DateTime.now();
      
      // Check if we need to generate daily missions
      final dailyMissionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('missions')
          .where('type', isEqualTo: 'daily')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .get();
      
      // Only generate daily missions if it's past 1 AM CET and we have no active missions
      if (dailyMissionsQuery.docs.isEmpty && now.hour >= 1) {
        await _generateDailyMissions(userId);
      }
      
      // Check if we need to generate weekly missions
      final weeklyMissionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('missions')
          .where('type', isEqualTo: 'weekly')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .get();
      
      // Only generate weekly missions if it's Monday past 1 AM CET and we have no active missions
      if (weeklyMissionsQuery.docs.isEmpty && now.weekday == DateTime.monday && now.hour >= 1) {
        await _generateWeeklyMissions(userId);
      }
    } catch (e) {
      logger.e('Error generating missions: $e');
    }
  }
  
  // Generate daily missions
  Future<void> _generateDailyMissions(String userId) async {
    final now = DateTime.now();
    // Calculate next 1 AM CET
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final expiresAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 1, 0, 0);
    
    // Normal mode daily missions
    final normalDailyMissions = [
      Mission(
        id: '',
        title: 'Daily Player',
        description: 'Play 3 games in normal mode',
        xpReward: 50,
        type: MissionType.daily,
        category: MissionCategory.normal,
        targetCount: 3,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'play_normal_game',
      ),
      Mission(
        id: '',
        title: 'Victory Lap',
        description: 'Win 1 game in normal mode',
        xpReward: 75,
        type: MissionType.daily,
        category: MissionCategory.normal,
        targetCount: 1,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'win_normal_game',
      ),
      Mission(
        id: '',
        title: 'Computer Challenger',
        description: 'Play 2 games against the computer',
        xpReward: 60,
        type: MissionType.daily,
        category: MissionCategory.normal,
        targetCount: 2,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'play_vs_computer',
      ),
    ];
    
    // Hell mode daily missions
    final hellDailyMissions = [
      Mission(
        id: '',
        title: 'Hell Visitor',
        description: 'Play 2 games in Hell Mode',
        xpReward: 100,
        type: MissionType.daily,
        category: MissionCategory.hell,
        targetCount: 2,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'play_hell_game',
      ),
      Mission(
        id: '',
        title: 'Hellish Victory',
        description: 'Win 1 game in Hell Mode',
        xpReward: 150,
        type: MissionType.daily,
        category: MissionCategory.hell,
        targetCount: 1,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'win_hell_game',
      ),
    ];
    
    // Save missions to Firestore
    final batch = _firestore.batch();
    final missionsCollection = _firestore.collection('users').doc(userId).collection('missions');
    
    // Add normal missions
    for (var mission in normalDailyMissions) {
      final docRef = missionsCollection.doc();
      batch.set(docRef, mission.toJson());
    }
    
    // Add hell missions
    for (var mission in hellDailyMissions) {
      final docRef = missionsCollection.doc();
      batch.set(docRef, mission.toJson());
    }
    
    await batch.commit();
    logger.i('Generated daily missions for user: $userId');
  }
  
  // Generate weekly missions
  Future<void> _generateWeeklyMissions(String userId) async {
    final now = DateTime.now();
    
    // Calculate next Monday at 1 AM CET
    int daysUntilMonday = (8 - now.weekday) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7; // If today is Monday, go to next Monday
    
    final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday);
    final expiresAt = DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 1, 0, 0);
    
    // Normal mode weekly missions
    final normalWeeklyMissions = [
      Mission(
        id: '',
        title: 'Weekly Warrior',
        description: 'Play 10 games in normal mode',
        xpReward: 200,
        type: MissionType.weekly,
        category: MissionCategory.normal,
        targetCount: 10,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'play_normal_game',
      ),
      Mission(
        id: '',
        title: 'Winning Streak',
        description: 'Win 5 games in normal mode',
        xpReward: 250,
        type: MissionType.weekly,
        category: MissionCategory.normal,
        targetCount: 5,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'win_normal_game',
      ),
      Mission(
        id: '',
        title: 'Hard Mode Master',
        description: 'Win 3 games against hard computer',
        xpReward: 300,
        type: MissionType.weekly,
        category: MissionCategory.normal,
        targetCount: 3,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'win_vs_hard_computer',
      ),
    ];
    
    // Hell mode weekly missions
    final hellWeeklyMissions = [
      Mission(
        id: '',
        title: 'Hell Dweller',
        description: 'Play 7 games in Hell Mode',
        xpReward: 350,
        type: MissionType.weekly,
        category: MissionCategory.hell,
        targetCount: 7,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'play_hell_game',
      ),
      Mission(
        id: '',
        title: 'Hell Conqueror',
        description: 'Win 3 games in Hell Mode',
        xpReward: 400,
        type: MissionType.weekly,
        category: MissionCategory.hell,
        targetCount: 3,
        currentCount: 0,
        completed: false,
        createdAt: now,
        expiresAt: expiresAt,
        missionKey: 'win_hell_game',
      ),
    ];
    
    // Save missions to Firestore
    final batch = _firestore.batch();
    final missionsCollection = _firestore.collection('users').doc(userId).collection('missions');
    
    // Add normal missions
    for (var mission in normalWeeklyMissions) {
      final docRef = missionsCollection.doc();
      batch.set(docRef, mission.toJson());
    }
    
    // Add hell missions
    for (var mission in hellWeeklyMissions) {
      final docRef = missionsCollection.doc();
      batch.set(docRef, mission.toJson());
    }
    
    await batch.commit();
    logger.i('Generated weekly missions for user: $userId');
  }
  
  // Track game played for missions
  Future<void> trackGamePlayed({
    required String userId,
    required bool isHellMode,
    required bool isWin,
    GameDifficulty? difficulty,
  }) async {
    if (userId.isEmpty) return;
    
    try {
      // Update mission progress based on game type
      if (isHellMode) {
        // Hell mode missions
        await updateMissionProgress(userId, 'play_hell_game', 1);
        
        if (isWin) {
          await updateMissionProgress(userId, 'win_hell_game', 1);
        }
      } else {
        // Normal mode missions
        await updateMissionProgress(userId, 'play_normal_game', 1);
        
        if (isWin) {
          await updateMissionProgress(userId, 'win_normal_game', 1);
        }
        
        // Computer-specific missions
        if (difficulty != null) {
          await updateMissionProgress(userId, 'play_vs_computer', 1);
          
          if (isWin && difficulty == GameDifficulty.hard) {
            await updateMissionProgress(userId, 'win_vs_hard_computer', 1);
          }
        }
      }
    } catch (e) {
      logger.e('Error tracking game for missions: $e');
    }
  }
}
