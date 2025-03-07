import 'package:cloud_firestore/cloud_firestore.dart';
import '../../logic/computer_player.dart';

class MatchHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveMatchResult({
    required String userId,
    required GameDifficulty difficulty,
    required String result,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('match_history')
        .add({
      'difficulty': difficulty.name,
      'result': result,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, int>> getMatchStats({
    required String userId,
    required GameDifficulty difficulty,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('match_history')
        .where('difficulty', isEqualTo: difficulty.name)
        .snapshots()
        .map((snapshot) {
      Map<String, int> stats = {
        'win': 0,
        'loss': 0,
        'draw': 0,
      };

      for (var doc in snapshot.docs) {
        final result = doc.data()['result'] as String;
        stats[result] = (stats[result] ?? 0) + 1;
      }

      return stats;
    });
  }

  Future<List<Map<String, dynamic>>> getRecentMatches({
    required String userId,
    required GameDifficulty difficulty,
    int limit = 10,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('match_history')
        .where('difficulty', isEqualTo: difficulty.name)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => {
              ...doc.data(),
              'id': doc.id,
            })
        .toList();
  }
}
