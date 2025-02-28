import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_account.dart';
import 'dart:developer' as developer;

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user stats
  Future<Map<String, GameStats>> getUserStats(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        throw Exception('User not found');
      }

      final data = doc.data();
      if (data == null) {
        throw Exception('User data is null');
      }

      // Convert the stats data to GameStats objects
      final vsComputerStats = GameStats.fromJson(
        _extractStats(data, 'vsComputerStats'),
      );
      
      final onlineStats = GameStats.fromJson(
        _extractStats(data, 'onlineStats'),
      );

      return {
        'vsComputerStats': vsComputerStats,
        'onlineStats': onlineStats,
      };
    } catch (e) {
      developer.log('Error fetching user stats: $e', error: e);
      rethrow; // Rethrow the exception for the caller to handle
    }
  }

  // Helper method to safely extract stats from Firestore data
  Map<String, dynamic> _extractStats(Map<String, dynamic> data, String key) {
    final stats = data[key];
    if (stats is Map<String, dynamic>) {
      return stats;
    }
    return {}; // Return an empty map if the stats are missing or invalid
  }
}