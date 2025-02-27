import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match.dart';
import 'dart:math';

class MatchmakingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection references
  final CollectionReference _matchmakingQueue;
  final CollectionReference _activeMatches;
  
  // Streams
  StreamSubscription? _matchSubscription;
  
  // Constructor
  MatchmakingService() 
    : _matchmakingQueue = FirebaseFirestore.instance.collection('matchmaking_queue'),
      _activeMatches = FirebaseFirestore.instance.collection('active_matches');
  
  DocumentReference? _currentQueueRef;
  StreamSubscription? _queueSubscription;
  Timer? _matchmakingTimer;
  
  // Find a match
  Future<String> findMatch() async {
    if (_auth.currentUser == null) {
      throw Exception('You must be logged in to play online');
    }
    
    try {
      final userId = _auth.currentUser!.uid;
      final username = _auth.currentUser!.displayName ?? 'Player';
      
      print('Starting matchmaking for user: $userId ($username)');
      
      // Add user to matchmaking queue with random symbol preference
      final wantsX = Random().nextBool();
      _currentQueueRef = await _matchmakingQueue.add({
        'userId': userId,
        'username': username,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'wantsX': wantsX, // Add random symbol preference
      });
      
      print('Added to matchmaking queue with ID: ${_currentQueueRef!.id}');
      
      // Look for other players in the queue
      try {
        // Wait for a match or timeout after 60 seconds
        print('Looking for opponent...');
        final matchId = await _findOpponent(_currentQueueRef!, userId);
        print('Match found with ID: $matchId');
        _currentQueueRef = null;
        return matchId;
      } catch (e) {
        // Clean up queue entry on error or timeout
        print('Error finding opponent: $e');
        await _cleanupMatchmaking();
        
        if (_currentQueueRef != null) {
          try {
            print('Cleaning up queue entry...');
            await _currentQueueRef!.delete();
            _currentQueueRef = null;
          } catch (deleteError) {
            print('Error deleting queue entry: $deleteError');
          }
        }
        
        throw Exception('Failed to find a match: ${e.toString()}');
      }
    } catch (e) {
      print('Error in findMatch: $e');
      await _cleanupMatchmaking();
      throw Exception('Error starting matchmaking: ${e.toString()}');
    }
  }
  
  // Find an opponent in the queue
  Future<String> _findOpponent(DocumentReference queueRef, String userId) async {
    Completer<String> completer = Completer<String>();
    
    // Set a timeout for matchmaking
    _matchmakingTimer = Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        print('Matchmaking timeout reached');
        _cleanupMatchmaking();
        completer.completeError('Matchmaking timeout');
      }
    });
    
    // Listen for status changes on our queue entry
    _queueSubscription = queueRef.snapshots().listen((snapshot) async {
      if (!completer.isCompleted) {
        final data = snapshot.data() as Map<String, dynamic>?;
        
        if (data != null) {
          // If we've been matched, return the match ID
          if (data['status'] == 'matched' && data['matchId'] != null) {
            final matchId = data['matchId'] as String;
            await _cleanupMatchmaking();
            completer.complete(matchId);
          }
          // Otherwise, try to find an opponent
          else if (data['status'] == 'waiting') {
            try {
              // Look for other waiting players - simplify query to avoid complex index requirements
              final querySnapshot = await _matchmakingQueue
                  .where('status', isEqualTo: 'waiting')
                  .limit(10)
                  .get();
                  
              // Filter results manually to find an opponent
              final filteredDocs = querySnapshot.docs
                  .where((doc) => doc['userId'] != userId)
                  .toList();
                  
              // Sort by timestamp if we have multiple candidates
              if (filteredDocs.isNotEmpty) {
                filteredDocs.sort((a, b) {
                  final aTime = a['timestamp'] as Timestamp;
                  final bTime = b['timestamp'] as Timestamp;
                  return aTime.compareTo(bTime);
                });
              }
              
              // If we found someone, create a match
              if (filteredDocs.isNotEmpty) {
                final opponentQueueRef = filteredDocs.first.reference;
                final opponentQueueData = filteredDocs.first.data() as Map<String, dynamic>;
                
                // Use transaction to ensure atomic updates
                final matchId = await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
                  // Verify both players are still available
                  final myQueueDoc = await transaction.get(queueRef);
                  final opponentQueueDoc = await transaction.get(opponentQueueRef);
                  
                  final myData = myQueueDoc.data() as Map<String, dynamic>?;
                  final opponentData = opponentQueueDoc.data() as Map<String, dynamic>?;
                  
                  if (!myQueueDoc.exists || !opponentQueueDoc.exists ||
                      myData == null || opponentData == null ||
                      myData['status'] != 'waiting' ||
                      opponentData['status'] != 'waiting') {
                    throw Exception('One or both players no longer available');
                  }
                  
                  // Create a new match
                  final matchId = await _createMatch(
                    userId, 
                    myData['username'] as String,  // Use myData instead of data
                    opponentQueueData['userId'] as String,
                    opponentQueueData['username'] as String,
                  );
                  
                  // Update both queue entries atomically
                  transaction.update(queueRef, {
                    'status': 'matched',
                    'matchId': matchId,
                  });
                  
                  transaction.update(opponentQueueRef, {
                    'status': 'matched',
                    'matchId': matchId,
                  });
                  
                  return matchId;
                });
                
                // Complete with the match ID
                _queueSubscription?.cancel();
                completer.complete(matchId);
              }
            } catch (e) {
              // Just log the error and continue waiting
              print('Error finding opponent: ${e.toString()}');
            }
          }
        }
      }
    }, onError: (error) {
      if (!completer.isCompleted) {
        completer.completeError('Queue error: ${error.toString()}');
      }
    });
    
    return completer.future;
  }
  
  // Create a new match
  Future<String> _createMatch(
    String player1Id, 
    String player1Name,
    String player2Id,
    String player2Name,
  ) async {
    // Randomly determine who goes first and assign symbols accordingly
    final random = Random();
    final player1GoesFirst = random.nextBool();
    final player1Symbol = player1GoesFirst ? 'X' : 'O';
    final player2Symbol = player1GoesFirst ? 'O' : 'X';
    
    // Create initial match state
    final Map<String, dynamic> matchData = {
      'player1': {
        'id': player1Id,
        'name': player1Name,
        'symbol': player1Symbol,
      },
      'player2': {
        'id': player2Id,
        'name': player2Name,
        'symbol': player2Symbol,
      },
      'xMoves': <int>[],  // Track X's moves in order
      'oMoves': <int>[],  // Track O's moves in order
      'xMoveCount': 0,    // Count of X's moves
      'oMoveCount': 0,    // Count of O's moves
      'board': List.filled(9, ''),
      'currentTurn': 'X', // X always goes first
      'status': 'active',
      'winner': '',
      'moveCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMoveAt': FieldValue.serverTimestamp(),
      'lastAction': {
        'type': 'game_start',
        'timestamp': FieldValue.serverTimestamp(),
      },
    };
    
    print('Creating new match with data: $matchData');
    final matchRef = await _activeMatches.add(matchData);
    
    return matchRef.id;
  }
  
  // Join an existing match
  Stream<GameMatch> joinMatch(String matchId) {
    // Clean up any existing subscriptions
    _matchSubscription?.cancel();
    
    if (_auth.currentUser == null) {
      throw Exception('You must be logged in to join a match');
    }
    
    // Create a StreamController to handle errors and transformations
    final controller = StreamController<GameMatch>();
    
    // Listen for match updates
    _matchSubscription = _activeMatches.doc(matchId).snapshots().listen(
      (snapshot) {
          if (!snapshot.exists) {
            print('Match not found: $matchId');
            controller.addError('Match not found');
            return;
          }

        Map<String, dynamic>? data;
        try {
          data = snapshot.data() as Map<String, dynamic>?;
        } catch (e) {
          print('Error casting match data: $e');
          controller.addError('Invalid match data format');
          return;
        }
        
          if (data == null) {
            print('Match data is null: $matchId');
            controller.addError('Match data is null');
            return;
          }

        try {
          final match = GameMatch.fromFirestore(data, matchId);
          if (match.board.length != 9) {
            controller.addError('Invalid board state');
            return;
          }
          controller.add(match);
        } catch (e) {
          print('Error parsing match data: $e');
          controller.addError('Invalid match data: ${e.toString()}');
        }
      },
      onError: (error) {
        print('Error in match stream: $error');
        controller.addError('Failed to connect to match: $error');
      },
      cancelOnError: false,
    );
    
    // Close the controller when the stream is cancelled
    controller.onCancel = () {
      _matchSubscription?.cancel();
      _matchSubscription = null;
    };
    
    return controller.stream;
  }
  
  // Make a move in a match
  Future<void> makeMove(String matchId, int position) async {
    if (_auth.currentUser == null) {
      throw Exception('You must be logged in to play');
    }
    
    print('Making move in match: $matchId, position: $position');
    final userId = _auth.currentUser!.uid;
    final matchRef = _activeMatches.doc(matchId);
    
    try {
      // Use a transaction to ensure data consistency
      return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchRef);
      
      if (!snapshot.exists) {
        throw Exception('Match not found');
      }
      
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Match data is null');
      }
      
      final GameMatch match;
      try {
        match = GameMatch.fromFirestore(data, matchId);
      } catch (e) {
        print('Error parsing match data: $e');
        throw Exception('Invalid match data: ${e.toString()}');
      }
      
      // Special case: position -1 means force state update to active
      if (position == -1) {
        // Reset the entire game state
        transaction.update(matchRef, {
          'status': 'active',
          'winner': '',
          'currentTurn': 'X',  // Reset to X's turn
          'moveCount': 0,
          'board': List.filled(9, ''),
          'xMoves': [],
          'oMoves': [],
          'xMoveCount': 0,
          'oMoveCount': 0,
          'lastMoveAt': FieldValue.serverTimestamp(),
          'lastAction': {
            'type': 'game_reset',
            'timestamp': FieldValue.serverTimestamp(),
          },
        });
        print('Resetting game state to active with player 1 (${match.player1.name}) starting');
        return;
      }
      
      // Verify game state is valid
      if (match.status == 'completed' && !match.board.every((cell) => cell.isEmpty)) {
        throw Exception('Cannot modify a completed game');
      }
      
      // Check if it's the player's turn
      final isPlayer1 = match.player1.id == userId;
      final isPlayer2 = match.player2.id == userId;
      
      if (!isPlayer1 && !isPlayer2) {
        throw Exception('You are not a player in this match');
      }
      
      final playerSymbol = isPlayer1 ? match.player1.symbol : match.player2.symbol;
      
      if (match.currentTurn != playerSymbol) {
        throw Exception('It is not your turn');
      }
      
      // Verify game is still active
      if (data['status'] != 'active') {
        throw Exception('Game is not active');
      }

      // Check if the position is valid
      if (position < 0 || position >= 9) {
        throw Exception('Invalid position');
      }
      
      // Create a new board state
      final List<String> newBoard = List<String>.from(data['board'] as List);
      
      // Check if the position is already taken
      if (newBoard[position].isNotEmpty) {
        throw Exception('Position already taken');
      }
      
      // Get current move count
      final int moveCount = (data['moveCount'] as int?) ?? 0;
      
      // Verify it's still the player's turn (prevent race conditions)
      if (data['currentTurn'] != playerSymbol) {
        throw Exception('Not your turn');
      }
      
      // Get current move lists
      List<int> xMoves = List<int>.from(data['xMoves'] as List? ?? []);
      List<int> oMoves = List<int>.from(data['oMoves'] as List? ?? []);
      int xMoveCount = (data['xMoveCount'] as int?) ?? 0;
      int oMoveCount = (data['oMoveCount'] as int?) ?? 0;
      
      // Update move tracking first
      if (playerSymbol == 'X') {
        xMoves.add(position);
        xMoveCount++;
      } else {
        oMoves.add(position);
        oMoveCount++;
      }

      // Apply the move
      newBoard[position] = playerSymbol;
      
      // Check for winner with this move
      bool hasWinner = _checkWin(newBoard, playerSymbol);
      
      // Only apply vanishing effect if there's no winner
      if (!hasWinner) {
        // Apply vanishing effect if needed (only for moves beyond the first 3)
        if (playerSymbol == 'X' && xMoveCount > 3) {
          newBoard[xMoves[0]] = '';
          xMoves.removeAt(0);
        } else if (playerSymbol == 'O' && oMoveCount > 3) {
          newBoard[oMoves[0]] = '';
          oMoves.removeAt(0);
        }
      }
      
      final nextTurn = playerSymbol == 'X' ? 'O' : 'X';
      final newMoveCount = moveCount + 1;
      
      // Prepare the update data
      final Map<String, dynamic> updateData = {
        'xMoves': xMoves,
        'oMoves': oMoves,
        'xMoveCount': xMoveCount,
        'oMoveCount': oMoveCount,
        'board': newBoard,
        'currentTurn': nextTurn,
        'lastMoveAt': FieldValue.serverTimestamp(),
        'moveCount': newMoveCount,
        'lastMove': {
          'position': position,
          'symbol': playerSymbol,
          'timestamp': FieldValue.serverTimestamp(),
        },
      };
      
      // Only update game status if there's a winner
      if (hasWinner) {
        updateData['status'] = 'completed';
        updateData['winner'] = playerSymbol;
        updateData['completedAt'] = FieldValue.serverTimestamp();
      } else if (newMoveCount >= 30) {
        updateData['status'] = 'completed';
        updateData['winner'] = 'draw';
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }
      
      // Update the match document
      transaction.update(matchRef, updateData);
      
      print('Move successfully applied: position=$position, symbol=$playerSymbol, hasWinner=$hasWinner, moveCount=$newMoveCount');
    }).catchError((error) {
      print('Error in transaction: $error');
      throw Exception('Failed to make move: $error');
    });
  } catch (e) {
    print('Error in makeMove: $e');
    throw Exception('Error making move: ${e.toString()}');
  }
  }

  // Cancel matchmaking
  Future<void> cancelMatchmaking() async {
    try {
      await _cleanupMatchmaking();
      
      if (_currentQueueRef != null) {
        print('Canceling matchmaking...');
        await _currentQueueRef!.delete();
        _currentQueueRef = null;
        print('Matchmaking canceled successfully');
      }
    } catch (e) {
      print('Error canceling matchmaking: $e');
      throw Exception('Failed to cancel matchmaking: ${e.toString()}');
    }
  }

  // Cleanup matchmaking resources
  Future<void> _cleanupMatchmaking() async {
    if (_queueSubscription != null) {
      await _queueSubscription!.cancel();
      _queueSubscription = null;
    }
    
    if (_matchmakingTimer != null) {
      _matchmakingTimer!.cancel();
      _matchmakingTimer = null;
    }
    
    if (_matchSubscription != null) {
      await _matchSubscription!.cancel();
      _matchSubscription = null;
    }
  }

  // Add a dispose method to clean up resources
  void dispose() {
    _cleanupMatchmaking();
    if (_currentQueueRef != null) {
      try {
        _currentQueueRef!.delete();
        _currentQueueRef = null;
      } catch (e) {
        print('Error deleting queue entry during dispose: $e');
      }
    }
  }
  
  // Check if a player has won
  bool _checkWin(List<String> board, String symbol) {
    // Check rows
    for (int i = 0; i < 9; i += 3) {
      if (board[i] == symbol && board[i + 1] == symbol && board[i + 2] == symbol) {
        return true;
      }
    }
    
    // Check columns
    for (int i = 0; i < 3; i++) {
      if (board[i] == symbol && board[i + 3] == symbol && board[i + 6] == symbol) {
        return true;
      }
    }
    
    // Check diagonals
    if (board[0] == symbol && board[4] == symbol && board[8] == symbol) {
      return true;
    }
    
    if (board[2] == symbol && board[4] == symbol && board[6] == symbol) {
      return true;
    }
    
    return false;
  }
  
  // Leave a match
  Future<void> leaveMatch(String matchId) async {
    // Clean up subscriptions
    _matchSubscription?.cancel();
    
    if (_auth.currentUser == null) {
      return;
    }
    
    final userId = _auth.currentUser!.uid;
    final matchRef = _activeMatches.doc(matchId);
    
    try {
      // Get the match data
      final snapshot = await matchRef.get();
      
      if (!snapshot.exists) {
        return;
      }
      
      final data = snapshot.data() as Map<String, dynamic>;
      
      // Safely access nested data
      final player1 = data['player1'] as Map<String, dynamic>?;
      final player2 = data['player2'] as Map<String, dynamic>?;
      
      if (player1 == null || player2 == null) {
        print('Error: Invalid match data structure');
        return;
      }
      
      final player1Id = player1['id'] as String?;
      final player2Id = player2['id'] as String?;
      
      if (player1Id == null || player2Id == null) {
        print('Error: Missing player IDs');
        return;
      }
      
      // If the user is a player in this match and it's still active, mark them as the loser
      if ((player1Id == userId || player2Id == userId) && data['status'] == 'active') {
        final winner = player1Id == userId ? player2['symbol'] as String? : player1['symbol'] as String?;
        
        if (winner == null) {
          print('Error: Missing player symbols');
          return;
        }
        
        await matchRef.update({
          'status': 'completed',
          'winner': winner,
          'lastMoveAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error leaving match: ${e.toString()}');
    }
  }
}
