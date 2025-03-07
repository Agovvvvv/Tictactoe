import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../../models/match.dart';

class FriendlyMatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _friendlyMatches;
  final CollectionReference _activeMatches;

  FriendlyMatchService() 
    : _friendlyMatches = FirebaseFirestore.instance.collection('friendlyMatches'),
      _activeMatches = FirebaseFirestore.instance.collection('active_matches');

  // Create a new match with a given code
  Future<void> createMatch({
    required String matchCode,
    required String hostId,
    required String hostName,
  }) async {
    try {
      // Check if match already exists
      final existingMatch = await _friendlyMatches.doc(matchCode).get();
      if (existingMatch.exists) {
        // If match exists but is old, we can overwrite it
        final data = existingMatch.data() as Map<String, dynamic>?;
        if (data != null) {
          final createdAt = data['createdAt'] as Timestamp?;
          final now = Timestamp.now();
          
          // If match is less than 1 hour old and not created by this user, don't overwrite
          if (createdAt != null && 
              now.seconds - createdAt.seconds < 3600 && 
              data['hostId'] != hostId) {
            throw Exception('Match code already in use');
          }
        }
      }
      
      // Create or update the match
      await _friendlyMatches.doc(matchCode).set({
        'hostId': hostId,
        'hostName': hostName,
        'guestId': null,
        'guestName': null,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'matchCode': matchCode,
      });
      developer.log('Created match with code: $matchCode');
    } catch (e) {
      developer.log('Error creating match: $e', error: e);
      throw Exception('Failed to create match: ${e.toString()}');
    }
  }

  // Join an existing match
  Future<String> joinMatch({
    required String matchCode,
    required String guestId,
    required String guestName,
  }) async {
    try {
      // Check if match exists and is waiting
      final matchDoc = await _friendlyMatches.doc(matchCode).get();
      
      if (!matchDoc.exists) {
        throw Exception('Match not found');
      }
      
      final matchData = matchDoc.data() as Map<String, dynamic>?;
      if (matchData == null || matchData['status'] != 'waiting') {
        throw Exception('Match is not available');
      }

      final hostId = matchData['hostId'] as String;
      final hostName = matchData['hostName'] as String;
      
      // Create an active match in the same format as online matches
      final activeMatchRef = _activeMatches.doc();
      final activeMatchId = activeMatchRef.id;
      
      // Randomly decide who plays X (goes first)
      //final hostPlaysX = true; // Host always plays X for simplicity
      
      // Create the active match
      await activeMatchRef.set({
        'player1': {
          'id': hostId,
          'name': hostName,
          'symbol': 'X'
        },
        'player2': {
          'id': guestId,
          'name': guestName,
          'symbol': 'O'
        },
        'board': List.filled(9, ''),
        'currentTurn': 'X', // X always goes first
        'status': 'active',
        'winner': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMoveAt': FieldValue.serverTimestamp(),
        'matchType': 'friendly',
        'matchCode': matchCode,
      });
      
      // Update the friendly match to point to the active match
      await _friendlyMatches.doc(matchCode).update({
        'guestId': guestId,
        'guestName': guestName,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'activeMatchId': activeMatchId,
      });
      
      developer.log('Joined match with code: $matchCode, active match ID: $activeMatchId');
      return activeMatchId;
    } catch (e) {
      developer.log('Error joining match: $e', error: e);
      throw Exception('Failed to join match: ${e.toString()}');
    }
  }

  // Get match data
  Future<Map<String, dynamic>?> getMatch(String matchCode) async {
    try {
      final matchDoc = await _friendlyMatches.doc(matchCode).get();
      
      if (!matchDoc.exists) {
        return null;
      }
      
      return matchDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      developer.log('Error getting match: $e', error: e);
      throw Exception('Failed to get match: ${e.toString()}');
    }
  }

  // Get active match data
  Future<GameMatch?> getActiveMatch(String activeMatchId) async {
    try {
      final matchDoc = await _activeMatches.doc(activeMatchId).get();
      
      if (!matchDoc.exists) {
        return null;
      }
      
      return GameMatch.fromFirestore(matchDoc.data() as Map<String, dynamic>?, activeMatchId);
    } catch (e) {
      developer.log('Error getting active match: $e', error: e);
      throw Exception('Failed to get active match: ${e.toString()}');
    }
  }

  // Make a move in an active match
  Future<void> makeMove(String activeMatchId, String playerId, int position) async {
    try {
      // Use a transaction to ensure atomic updates and prevent race conditions
      await _firestore.runTransaction((transaction) async {
        // Get the current match state
        final matchDoc = await transaction.get(_activeMatches.doc(activeMatchId));
        if (!matchDoc.exists) {
          throw Exception('Match not found');
        }
        
        final matchData = matchDoc.data() as Map<String, dynamic>?;
        if (matchData == null) {
          throw Exception('Match data is null');
        }
        
        // Check if it's the player's turn
        final player1 = matchData['player1'] as Map<String, dynamic>;
        final player2 = matchData['player2'] as Map<String, dynamic>;
        final board = List<String>.from((matchData['board'] as List).map((e) => (e ?? '').toString()));
        final currentTurn = matchData['currentTurn'] as String;
        final status = matchData['status'] as String;
        
        // Validate move
        if (status != 'active') {
          throw Exception('Game is not active');
        }
        
        final playerSymbol = player1['id'] == playerId ? player1['symbol'] : player2['symbol'];
        if (playerSymbol != currentTurn) {
          throw Exception('Not your turn');
        }
        
        if (position < 0 || position >= 9) {
          throw Exception('Invalid position');
        }
        
        if (board[position].isNotEmpty) {
          throw Exception('Position already taken');
        }
        
        // Make the move
        board[position] = playerSymbol;
        
        // Check for win or draw BEFORE any vanishing effect
        String winner = '';
        bool isDraw = false;
        
        // Check rows, columns, and diagonals for a win
        final winPatterns = [
          [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
          [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
          [0, 4, 8], [2, 4, 6]             // diagonals
        ];
        
        // Print the current board state for debugging
        developer.log('Current board state after move: ${board.join(",")}');
        
        for (final pattern in winPatterns) {
          if (board[pattern[0]].isNotEmpty &&
              board[pattern[0]] == board[pattern[1]] &&
              board[pattern[0]] == board[pattern[2]]) {
            winner = board[pattern[0]];
            developer.log('Win detected in pattern ${pattern.join(",")} with symbol $winner');
            developer.log('Win pattern values: ${board[pattern[0]]}, ${board[pattern[1]]}, ${board[pattern[2]]}');
            break;
          }
        }
        
        // Check for draw if no winner
        if (winner.isEmpty && !board.contains('')) {
          isDraw = true;
          developer.log('Draw detected - board is full with no winner');
        }
        
        // Update the match
        final nextTurn = currentTurn == 'X' ? 'O' : 'X';
        
        // Apply vanishing effect AFTER checking for win condition
        // Only apply vanishing if the game is still active
        
        // Create update data map
        final Map<String, dynamic> updateData = {
          'board': board,
          'currentTurn': nextTurn,
          'lastMoveAt': FieldValue.serverTimestamp(),
        };
        
        // If we have a winner or draw, update the status and winner fields
        if (winner.isNotEmpty || isDraw) {
          updateData['status'] = 'completed';
          updateData['winner'] = isDraw ? 'draw' : winner;
          developer.log('Setting game as completed with winner: ${isDraw ? "draw" : winner}');
        } else {
          updateData['status'] = 'active';
          updateData['winner'] = '';
        }
        
        // Update the match in the transaction
        transaction.update(_activeMatches.doc(activeMatchId), updateData);
        
        developer.log('Move made in match $activeMatchId by player $playerId at position $position');
        developer.log('Game status: ${winner.isNotEmpty || isDraw ? "completed" : "active"}, Winner: ${isDraw ? "draw" : winner}');
      });
    } catch (e) {
      developer.log('Error making move: $e', error: e);
      throw Exception('Failed to make move: ${e.toString()}');
    }
  }

  // Listen for updates to an active match
  Stream<GameMatch?> listenForActiveMatchUpdates(String activeMatchId) {
    return _activeMatches
        .doc(activeMatchId)
        .snapshots()
        .map((snapshot) => snapshot.exists
            ? GameMatch.fromFirestore(snapshot.data() as Map<String, dynamic>?, activeMatchId)
            : null);
  }

  // Listen for updates to a friendly match
  Stream<Map<String, dynamic>?> listenForMatchUpdates(String matchCode) {
    return _friendlyMatches
        .doc(matchCode)
        .snapshots()
        .map((snapshot) => snapshot.data() as Map<String, dynamic>?);
  }

  // Delete a match
  Future<void> deleteMatch(String matchCode) async {
    try {
      // Get the match to check if there's an active match to delete
      final matchDoc = await _friendlyMatches.doc(matchCode).get();
      if (matchDoc.exists) {
        final matchData = matchDoc.data() as Map<String, dynamic>?;
        if (matchData != null && matchData['activeMatchId'] != null) {
          // Delete the active match first
          await _activeMatches.doc(matchData['activeMatchId']).delete();
        }
      }
      
      // Delete the friendly match
      await _friendlyMatches.doc(matchCode).delete();
      developer.log('Deleted match with code: $matchCode');
    } catch (e) {
      developer.log('Error deleting match: $e', error: e);
      throw Exception('Failed to delete match: ${e.toString()}');
    }
  }

  // Clean up old matches (can be called periodically)
  Future<void> cleanupOldMatches() async {
    try {
      // Get matches older than 1 hour
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      final snapshot = await _friendlyMatches
          .where('createdAt', isLessThan: cutoff)
          .get();
      
      // Delete old matches
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final matchData = doc.data() as Map<String, dynamic>?;
        if (matchData != null && matchData['activeMatchId'] != null) {
          // Delete the active match first
          batch.delete(_activeMatches.doc(matchData['activeMatchId']));
        }
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      developer.log('Cleaned up ${snapshot.docs.length} old matches');
    } catch (e) {
      developer.log('Error cleaning up old matches: $e', error: e);
    }
  }
}
