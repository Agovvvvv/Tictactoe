import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/match.dart';
import '../../models/utils/logger.dart';
import '../../models/utils/win_checker.dart';

class MatchmakingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _activeMatches;
  final CollectionReference _matchmakingQueue;
  StreamSubscription? _matchSubscription;

  MatchmakingService() :
    _activeMatches = FirebaseFirestore.instance.collection('matches'),
    _matchmakingQueue = FirebaseFirestore.instance.collection('matchmaking_queue');

  DocumentReference? _currentQueueRef;
  StreamSubscription? _queueSubscription;
  Timer? _matchmakingTimer;


  // Find a match
  Future<String> findMatch({bool isHellMode = false}) async {
    if (_auth.currentUser == null) {
      throw Exception('You must be logged in to play online');
    }

    try {
      final userId = _auth.currentUser!.uid;
      final username = _auth.currentUser!.displayName ?? 'Player';

      logger.i('Starting matchmaking for user: $userId ($username), isHellMode: $isHellMode');      

      final wantsX = Random().nextBool();
      _currentQueueRef = await _matchmakingQueue.add({
        'userId': userId,
        'username': username,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'wantsX': wantsX,
        'isHellMode': isHellMode,
      });

      logger.i('Added to matchmaking queue with ID: ${_currentQueueRef!.id}');

      try {
        final matchId = await _findOpponent(_currentQueueRef!, userId, isHellMode);
        logger.i('Match found with ID: $matchId');
        _currentQueueRef = null;
        return matchId;
      } catch (e) {
        logger.e('Error finding opponent: $e');
        await _cleanupMatchmaking();
        if (_currentQueueRef != null) {
          try {
            await _currentQueueRef!.delete();
            _currentQueueRef = null;
          } catch (deleteError) {
            logger.e('Error deleting queue entry: $deleteError');
          }
        }
        throw Exception('Failed to find a match: ${e.toString()}');
      }
    } catch (e) {
      logger.e('Error in findMatch: $e');
      await _cleanupMatchmaking();
      throw Exception('Error starting matchmaking: ${e.toString()}');
    }
  }

  // Find an opponent in the queue
  Future<String> _findOpponent(DocumentReference queueRef, String userId, bool isHellMode) async {
    Completer<String> completer = Completer<String>();

    _matchmakingTimer = Timer(const Duration(minutes: 3), () {
      if (!completer.isCompleted) {
        logger.i('Matchmaking timeout reached');
        _cleanupMatchmaking();
        completer.completeError('Matchmaking timeout');
      }
    });

    _queueSubscription = queueRef.snapshots().listen((snapshot) async {
      if (!completer.isCompleted) {
        final data = snapshot.data() as Map<String, dynamic>?;

        if (data != null) {
          if (data['status'] == 'matched' && data['matchId'] != null) {
            final matchId = data['matchId'] as String;
            await _cleanupMatchmaking();
            completer.complete(matchId);
          } else if (data['status'] == 'waiting') {
            try {
              final querySnapshot = await _matchmakingQueue
                  .where('status', isEqualTo: 'waiting')
                  .where('isHellMode', isEqualTo: isHellMode)
                  .limit(10)
                  .get();

              final filteredDocs = querySnapshot.docs.where((doc) => doc['userId'] != userId).toList();

              logger.i('Found ${filteredDocs.length} potential opponents with matching preferences');

              if (filteredDocs.isNotEmpty) {
                filteredDocs.sort((a, b) {
                  final aTime = a['timestamp'] as Timestamp;
                  final bTime = b['timestamp'] as Timestamp;
                  return aTime.compareTo(bTime);
                });
              }

              if (filteredDocs.isNotEmpty) {
                final opponentQueueRef = filteredDocs.first.reference;
                final opponentQueueData = filteredDocs.first.data() as Map<String, dynamic>;
                final opponentUserId = opponentQueueData['userId'] as String;
                final opponentUsername = opponentQueueData['username'] as String;

                logger.i('Found potential opponent: $opponentUsername ($opponentUserId)');

                late final DocumentReference matchRef;
                late final String matchId;
                bool matchCreated = false;
                
                try {
                  final myQueueDoc = await queueRef.get();
                  final myData = myQueueDoc.data() as Map<String, dynamic>?;
                  
                  if (myData == null) {
                    throw Exception('Queue data is null');
                  }

                  // First prepare the match data outside the transaction
                  matchRef = _activeMatches.doc();
                  matchId = matchRef.id;
                  logger.i('Creating new match with ID: $matchId');

                  final Map<String, dynamic> matchData = await _prepareMatchData(
                    userId,
                    myData['username'] as String,
                    opponentUserId,
                    opponentUsername,
                    isHellMode,
                  );

                  // Create the match document first
                  await matchRef.set(matchData);
                  matchCreated = true;
                  logger.i('Match document created successfully');

                  // Now run the transaction for queue updates
                  await FirebaseFirestore.instance.runTransaction((transaction) async {
                    final freshMyQueueDoc = await transaction.get(queueRef);
                    final freshOpponentQueueDoc = await transaction.get(opponentQueueRef);

                    if (!freshMyQueueDoc.exists || !freshOpponentQueueDoc.exists) {
                      throw Exception('One or both players no longer available');
                    }

                    final freshMyData = freshMyQueueDoc.data() as Map<String, dynamic>?;
                    final freshOpponentData = freshOpponentQueueDoc.data() as Map<String, dynamic>?;

                    if (freshMyData == null || freshOpponentData == null) {
                      throw Exception('One or both players have null data');
                    }

                    if (freshMyData['status'] != 'waiting' || freshOpponentData['status'] != 'waiting') {
                      throw Exception('One or both players are not in waiting status');
                    }

                    // Update queue entries
                    final queueUpdate = {
                      'status': 'matched',
                      'matchId': matchId,
                      'matchTimestamp': FieldValue.serverTimestamp(),
                    };

                    transaction.update(queueRef, queueUpdate);
                    transaction.update(opponentQueueRef, queueUpdate);

                    logger.i('Queue entries updated successfully');
                  });

                  logger.i('Match created successfully with ID: $matchId');
                  _queueSubscription?.cancel();
                  completer.complete(matchId);
                } catch (e) {
                  logger.e('Transaction failed: $e');
                  // Clean up the match document if it was created
                  if (matchCreated) {
                    try {
                      await matchRef.delete();
                      logger.i('Successfully cleaned up failed match');
                    } catch (deleteError) {
                      logger.e('Error cleaning up failed match: $deleteError');
                    }
                  }
                }
              }
            } catch (e) {
              logger.e('Error finding opponent: ${e.toString()}');
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

  // Prepare match data
  Future<Map<String, dynamic>> _prepareMatchData(
    String player1Id,
    String player1Name,
    String player2Id,
    String player2Name,
    bool isHellMode,
  ) async {
    final random = Random();
    final player1GoesFirst = random.nextBool();
    final player1Symbol = player1GoesFirst ? 'X' : 'O';
    final player2Symbol = player1GoesFirst ? 'O' : 'X';

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
      'xMoves': <int>[],
      'oMoves': <int>[],
      'xMoveCount': 0,
      'oMoveCount': 0,
      'board': List.filled(9, ''),
      'currentTurn': 'X',
      'status': 'active',
      'winner': null,
      'moveCount': 0,
      'isHellMode': isHellMode,
      'matchType': 'casual',
      'createdAt': FieldValue.serverTimestamp(),
      'lastMoveAt': FieldValue.serverTimestamp(),
      'lastAction': {
        'type': 'game_start',
        'timestamp': FieldValue.serverTimestamp(),
      },
    };

    return matchData;
  }

  // Join an existing match
  Stream<GameMatch> joinMatch(String matchId) {
    _matchSubscription?.cancel();

    if (_auth.currentUser == null) {
      throw Exception('You must be logged in to join a match');
    }

    final controller = StreamController<GameMatch>();

    _matchSubscription = _activeMatches.doc(matchId).snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) {
          logger.i('Match not found: $matchId');
          controller.addError('Match not found');
          return;
        }

        Map<String, dynamic>? data;
        try {
          data = snapshot.data() as Map<String, dynamic>?;
        } catch (e) {
          logger.e('Error casting match data: $e');
          controller.addError('Invalid match data format');
          return;
        }

        if (data == null) {
          logger.w('Match data is null: $matchId');
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
          logger.e('Error parsing match data: $e');
          controller.addError('Invalid match data: ${e.toString()}');
        }
      },
      onError: (error) {
        logger.e('Error in match stream: $error');
        controller.addError('Failed to connect to match: $error');
      },
      cancelOnError: false,
    );

    controller.onCancel = () {
      _matchSubscription?.cancel();
      _matchSubscription = null;
    };

    return controller.stream;
  }

  Future<void> makeMove(String matchId, int position) async {
  if (_auth.currentUser == null) {
    throw Exception('You must be logged in to play');
  }

  logger.i('Making move in match: $matchId, position: $position');
  final userId = _auth.currentUser!.uid;
  final matchRef = _activeMatches.doc(matchId);

  try {
    await FirebaseFirestore.instance.runTransaction<Map<String, dynamic>>((transaction) async {
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
        logger.e('Error parsing match data: $e');
        throw Exception('Invalid match data: ${e.toString()}');
      }

      if (position == -1) {
        transaction.update(matchRef, {
          'status': 'active',
          'winner': '',
          'currentTurn': 'X',
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
        logger.i('Resetting game state to active with player 1 (${match.player1.name}) starting');
        return {
          'matchId': matchId,
          'isCompleted': false
        };
      }

      if (match.status == 'completed' && !match.board.every((cell) => cell.isEmpty)) {
        throw Exception('Cannot modify a completed game');
      }

      final isPlayer1 = match.player1.id == userId;
      final isPlayer2 = match.player2.id == userId;

      if (!isPlayer1 && !isPlayer2) {
        throw Exception('You are not a player in this match');
      }

      final playerSymbol = isPlayer1 ? match.player1.symbol : match.player2.symbol;

      if (match.currentTurn != playerSymbol) {
        throw Exception('It is not your turn');
      }

      if (data['status'] != 'active') {
        throw Exception('Game is not active');
      }

      if (position < 0 || position >= 9) {
        throw Exception('Invalid position');
      }

      final List<String> newBoard = List<String>.from(data['board'] as List);

      if (newBoard[position].isNotEmpty) {
        throw Exception('Position already taken');
      }

      final int moveCount = (data['moveCount'] as int?) ?? 0;

      if (data['currentTurn'] != playerSymbol) {
        throw Exception('Not your turn');
      }

      List<int> xMoves = List<int>.from(data['xMoves'] as List? ?? []);
      List<int> oMoves = List<int>.from(data['oMoves'] as List? ?? []);
      int xMoveCount = (data['xMoveCount'] as int?) ?? 0;
      int oMoveCount = (data['oMoveCount'] as int?) ?? 0;

      if (playerSymbol == 'X') {
        xMoves.add(position);
        xMoveCount++;
      } else {
        oMoves.add(position);
        oMoveCount++;
      }

      newBoard[position] = playerSymbol;

      bool hasWinner = WinChecker.checkWin(newBoard, playerSymbol);

      if (!hasWinner) {
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
      
      if (hasWinner) {
        updateData['status'] = 'completed';
        updateData['winner'] = playerSymbol == match.player1.symbol 
            ? match.player1.id 
            : match.player2.id; // Store the player ID
        updateData['completedAt'] = FieldValue.serverTimestamp();
      } else if (newMoveCount >= 30) {
        updateData['status'] = 'completed';
        updateData['winner'] = 'draw';
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      transaction.update(matchRef, updateData);

      logger.i('Move successfully applied: position=$position, symbol=$playerSymbol, hasWinner=$hasWinner, moveCount=$newMoveCount');
      
      // Return information needed for post-transaction operations
      return {
        'matchId': matchId,
        'isCompleted': hasWinner || newMoveCount >= 30
      };
    });
    
  } catch (e) {
    logger.e('Error in makeMove: $e');
    throw Exception('Error making move: ${e.toString()}');
  }
}

  // Cancel matchmaking
  Future<void> cancelMatchmaking() async {
    try {
      await _cleanupMatchmaking();

      if (_currentQueueRef != null) {
        logger.i('Canceling matchmaking...');
        await _currentQueueRef!.delete();
        _currentQueueRef = null;
        logger.i('Matchmaking canceled successfully');
      }
    } catch (e) {
      logger.e('Error canceling matchmaking: $e');
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

  // Dispose method to clean up resources
  void dispose() {
    _cleanupMatchmaking();
    if (_currentQueueRef != null) {
      try {
        _currentQueueRef!.delete();
        _currentQueueRef = null;
      } catch (e) {
        logger.e('Error deleting queue entry during dispose: $e');
      }
    }
  }

  Future<void> leaveMatch(String matchId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _activeMatches.doc(matchId).update({
        'status': 'completed',
        'winner': null,
        'endReason': 'player_left',
        'endTimestamp': FieldValue.serverTimestamp(),
      });

      logger.i('Player ${currentUser.uid} left match $matchId');
    } catch (e) {
      logger.e('Error leaving match: $e');
      rethrow;
    }
  }



}