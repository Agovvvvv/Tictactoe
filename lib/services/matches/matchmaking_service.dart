import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/match.dart';
import '../../models/rank_system.dart';
import '../../models/utils/logger.dart';
import '../../models/utils/win_checker.dart'; // Utility for win condition checking

class MatchmakingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CollectionReference _matchmakingQueue;
  final CollectionReference _activeMatches;

  StreamSubscription? _matchSubscription;
  DocumentReference? _currentQueueRef;
  StreamSubscription? _queueSubscription;
  Timer? _matchmakingTimer;

  MatchmakingService()
      : _matchmakingQueue = FirebaseFirestore.instance.collection('matchmaking_queue'),
        _activeMatches = FirebaseFirestore.instance.collection('active_matches');

  // Find a match
  Future<String> findMatch({bool isRanked = false, bool isHellMode = false}) async {
    if (_auth.currentUser == null) {
      throw Exception('You must be logged in to play online');
    }

    try {
      final userId = _auth.currentUser!.uid;
      final username = _auth.currentUser!.displayName ?? 'Player';

      logger.i('Starting matchmaking for user: $userId ($username), isRanked: $isRanked, isHellMode: $isHellMode');

      int mmr = RankSystem.initialMmr;
      if (isRanked) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists && userDoc.data() != null) {
            mmr = userDoc.data()!['mmr'] ?? RankSystem.initialMmr;
          }
        } catch (e) {
          logger.e('Error fetching user MMR: $e');
        }
      }

      final wantsX = Random().nextBool();
      _currentQueueRef = await _matchmakingQueue.add({
        'userId': userId,
        'username': username,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'wantsX': wantsX,
        'isRanked': isRanked,
        'isHellMode': isHellMode,
        'mmr': mmr,
      });

      logger.i('Added to matchmaking queue with ID: ${_currentQueueRef!.id}');

      try {
        final matchId = await _findOpponent(_currentQueueRef!, userId, isRanked, isHellMode);
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
  Future<String> _findOpponent(DocumentReference queueRef, String userId, bool isRanked, bool isHellMode) async {
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
                  .where('isRanked', isEqualTo: isRanked)
                  .where('isHellMode', isEqualTo: isHellMode)
                  .limit(10)
                  .get();

              final filteredDocs = querySnapshot.docs.where((doc) => doc['userId'] != userId).toList();

              logger.i('Found ${filteredDocs.length} potential opponents with matching preferences');

              if (filteredDocs.isNotEmpty) {
                if (isRanked) {
                  final myMmr = data['mmr'] as int? ?? RankSystem.initialMmr;
                  filteredDocs.sort((a, b) {
                    final aMmr = a['mmr'] as int? ?? RankSystem.initialMmr;
                    final bMmr = b['mmr'] as int? ?? RankSystem.initialMmr;
                    final aDiff = (aMmr - myMmr).abs();
                    final bDiff = (bMmr - myMmr).abs();
                    if ((aDiff - bDiff).abs() < 100) {
                      final aTime = a['timestamp'] as Timestamp;
                      final bTime = b['timestamp'] as Timestamp;
                      return aTime.compareTo(bTime);
                    }
                    return aDiff.compareTo(bDiff);
                  });
                } else {
                  filteredDocs.sort((a, b) {
                    final aTime = a['timestamp'] as Timestamp;
                    final bTime = b['timestamp'] as Timestamp;
                    return aTime.compareTo(bTime);
                  });
                }
              }

              if (filteredDocs.isNotEmpty) {
                final opponentQueueRef = filteredDocs.first.reference;
                final opponentQueueData = filteredDocs.first.data() as Map<String, dynamic>;
                final opponentUserId = opponentQueueData['userId'] as String;
                final opponentUsername = opponentQueueData['username'] as String;

                logger.i('Found potential opponent: $opponentUsername ($opponentUserId)');

                try {
                  final matchId = await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
                    final myQueueDoc = await transaction.get(queueRef);
                    final opponentQueueDoc = await transaction.get(opponentQueueRef);

                    if (!myQueueDoc.exists || !opponentQueueDoc.exists) {
                      throw Exception('One or both players no longer available');
                    }

                    final myData = myQueueDoc.data() as Map<String, dynamic>?;
                    final opponentData = opponentQueueDoc.data() as Map<String, dynamic>?;

                    if (myData == null || opponentData == null) {
                      throw Exception('One or both players have null data');
                    }

                    if (myData['status'] != 'waiting' || opponentData['status'] != 'waiting') {
                      throw Exception('One or both players are not in waiting status');
                    }

                    final matchRef = _activeMatches.doc();
                    final matchId = matchRef.id;

                    logger.i('Creating new match with ID: $matchId');

                    final Map<String, dynamic> matchData = _prepareMatchData(
                      userId,
                      myData['username'] as String,
                      opponentUserId,
                      opponentUsername,
                      isRanked,
                      isHellMode,
                    );

                    transaction.set(matchRef, matchData);

                    transaction.update(queueRef, {
                      'status': 'matched',
                      'matchId': matchId,
                      'matchTimestamp': FieldValue.serverTimestamp(),
                    });

                    transaction.update(opponentQueueRef, {
                      'status': 'matched',
                      'matchId': matchId,
                      'matchTimestamp': FieldValue.serverTimestamp(),
                    });

                    logger.i('Transaction completed successfully');
                    return matchId;
                  });

                  logger.i('Match created successfully with ID: $matchId');
                  _queueSubscription?.cancel();
                  completer.complete(matchId);
                } catch (e) {
                  logger.e('Transaction failed: $e');
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
  Map<String, dynamic> _prepareMatchData(
    String player1Id,
    String player1Name,
    String player2Id,
    String player2Name,
    bool isRanked,
    bool isHellMode,
  ) {
    final random = Random();
    final player1GoesFirst = random.nextBool();
    final player1Symbol = player1GoesFirst ? 'X' : 'O';
    final player2Symbol = player1GoesFirst ? 'O' : 'X';

    int player1Mmr = RankSystem.initialMmr;
    int player2Mmr = RankSystem.initialMmr;

    final Map<String, dynamic> matchData = {
      'player1': {
        'id': player1Id,
        'name': player1Name,
        'symbol': player1Symbol,
        'mmr': player1Mmr,
      },
      'player2': {
        'id': player2Id,
        'name': player2Name,
        'symbol': player2Symbol,
        'mmr': player2Mmr,
      },
      'xMoves': <int>[],
      'oMoves': <int>[],
      'xMoveCount': 0,
      'oMoveCount': 0,
      'board': List.filled(9, ''),
      'currentTurn': 'X',
      'status': 'active',
      'winner': '',
      'moveCount': 0,
      'isRanked': isRanked,
      'isHellMode': isHellMode,
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
        return;
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

        if (data['isRanked'] == true) {
          logger.i('Updating MMR for player: $updateData[\'winner\']');
          await _updatePlayerMmr(matchId);
        }
      } else if (newMoveCount >= 30) {
        updateData['status'] = 'completed';
        updateData['winner'] = 'draw';
        updateData['completedAt'] = FieldValue.serverTimestamp();

        if (data['isRanked'] == true) {
          await _updatePlayerMmr(matchId);
        }
      }

      transaction.update(matchRef, updateData);

      logger.i('Move successfully applied: position=$position, symbol=$playerSymbol, hasWinner=$hasWinner, moveCount=$newMoveCount');
    }).catchError((error) {
      logger.e('Error in transaction: $error');
      throw Exception('Failed to make move: $error');
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

  // Check if a player has won
  bool _checkWin(List<String> board, String symbol) {
    return WinChecker.checkWin(board, symbol);
  }

  Future<void> _updatePlayerMmr(String matchId) async {
  try {
    final matchDoc = await _activeMatches.doc(matchId).get();
    if (!matchDoc.exists) return;

    final data = matchDoc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final isRanked = data['isRanked'] as bool? ?? false;
    final status = data['status'] as String? ?? 'active';
    final isHellMode = data['isHellMode'] as bool? ?? false;

    if (!isRanked || status == 'active') return;

    final player1 = data['player1'] as Map<String, dynamic>?;
    final player2 = data['player2'] as Map<String, dynamic>?;
    final winner = data['winner'] as String? ?? '';

    if (player1 == null || player2 == null) return;

    final player1Id = player1['id'] as String?;
    final player2Id = player2['id'] as String?;

    if (player1Id == null || player2Id == null) return;

    final isDraw = winner.isEmpty || winner == 'draw';
    final player1MMR = player1['mmr'];
    final player2MMR = player2['mmr'];
    // Update MMR for both players
    await _updateSinglePlayerMmr(
                                playerId: player1Id, 
                                isDraw: isDraw, 
                                isHellMode: isHellMode, 
                                isWin: winner == player1Id,
                                opponentMmr: player2MMR,
                                playerMmr: player1MMR
                              ); // Update player 1
    await _updateSinglePlayerMmr(
                                playerId: player2Id, 
                                isDraw: isDraw, 
                                isHellMode: isHellMode, 
                                isWin: winner == player2Id,
                                opponentMmr: player1MMR,
                                playerMmr: player2MMR
                              ); // Update player 2

    // Call updateRankPoints after updating MMR
    await updateRankPoints(
      matchId,
      player1Id,
      player2Id,
      winner,
      isDraw,
    );

    logger.i('Updated MMR and rank points for both players in match $matchId');
  } catch (e) {
    logger.e('Error updating player MMR: $e');
  }
}

  // Helper method to update a single player's ranking
  Future<void> _updateSinglePlayerMmr({
    required String playerId,
    required bool isWin,
    required bool isDraw,
    required int playerMmr,
    required int opponentMmr,
    required bool isHellMode,
  }) async {
    try {
      final mmrChange = RankSystem.calculateMmrChange(
        isWin: isWin,
        isDraw: isDraw,
        playerMmr: playerMmr,
        opponentMmr: opponentMmr,
        isHellMode: isHellMode,
      );

      final rankPointsChange = RankSystem.calculateRankPointsChange(
        isWin: isWin,
        isDraw: isDraw,
        playerMmr: playerMmr,
        opponentMmr: opponentMmr,
        isHellMode: isHellMode,
      );

      logger.i('Player $playerId: MMR change: $mmrChange, Rank points change: $rankPointsChange');

      if (mmrChange == 0 && rankPointsChange == 0) return;

      final usersCollection = _firestore.collection('users');
      final userDoc = await usersCollection.doc(playerId).get();
      if (!userDoc.exists) {
        logger.w('User document not found for player $playerId');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) {
        logger.w('User data is null for player $playerId');
        return;
      }

      final currentMmr = userData['mmr'] as int? ?? RankSystem.initialMmr;
      final currentRankPoints = userData['rankPoints'] as int? ?? RankSystem.initialRankPoints;

      final newMmr = (currentMmr + mmrChange).clamp(0, 10000);
      final newRankPoints = (currentRankPoints + rankPointsChange).clamp(0, 10000);

      final currentRankStr = userData['rank'] as String? ?? Rank.bronze.toString().split('.').last;
      final currentDivisionStr = userData['division'] as String? ?? Division.iv.toString().split('.').last;

      Rank currentRank;
      try {
        currentRank = Rank.values.firstWhere(
          (r) => r.toString().split('.').last == currentRankStr,
          orElse: () => RankSystem.getRankFromPoints(currentRankPoints),
        );
      } catch (_) {
        currentRank = RankSystem.getRankFromPoints(currentRankPoints);
      }

      Division currentDivision;
      try {
        currentDivision = Division.values.firstWhere(
          (d) => d.toString().split('.').last == currentDivisionStr,
          orElse: () => RankSystem.getDivisionFromPoints(currentRankPoints, currentRank),
        );
      } catch (_) {
        currentDivision = RankSystem.getDivisionFromPoints(currentRankPoints, currentRank);
      }

      final newRank = RankSystem.getRankFromPoints(newRankPoints);
      final newDivision = RankSystem.getDivisionFromPoints(newRankPoints, newRank);

      final oldRankDisplay = RankSystem.getFullRankDisplay(currentRank, currentDivision);
      final newRankDisplay = RankSystem.getFullRankDisplay(newRank, newDivision);

      await usersCollection.doc(playerId).update({
        'mmr': newMmr,
        'rankPoints': newRankPoints,
        'rank': newRank.toString().split('.').last,
        'division': newDivision.toString().split('.').last,
        'lastRankPointsChange': rankPointsChange,
        'previousDivision': oldRankDisplay != newRankDisplay ? oldRankDisplay : null,
      });

      final mmrChangeSymbol = mmrChange > 0 ? '+' : '';
      final rankPointsChangeSymbol = rankPointsChange > 0 ? '+' : '';

      logger.i('Player $playerId MMR changed by $mmrChangeSymbol$mmrChange. New MMR: $newMmr');
      logger.i('Player $playerId Rank Points changed by $rankPointsChangeSymbol$rankPointsChange. New Rank Points: $newRankPoints');

      if (oldRankDisplay != newRankDisplay) {
        logger.i('Player $playerId rank changed from $oldRankDisplay to $newRankDisplay!');
      }
    } catch (e) {
      logger.e('Error updating player ranking: $e');
      if (e is FirebaseException) {
        logger.e('Firebase error code: ${e.code}, message: ${e.message}');
      }
    }
  }

  // Update rank points and MMR after a match
  Future<void> updateRankPoints(
    String matchId,
    String player1Id,
    String player2Id,
    String? winnerId,
    bool isDraw,
  ) async {
    try {
      logger.i('Updating rank points for match $matchId');
      logger.d('Player1: $player1Id, Player2: $player2Id, Winner: $winnerId, Draw: $isDraw');

      await _activeMatches.doc(matchId).update({
        'rankPointsUpdated': true,
        'rankUpdateTimestamp': FieldValue.serverTimestamp(),
      });

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final player1Doc = await _firestore.collection('users').doc(player1Id).get();
      final player2Doc = await _firestore.collection('users').doc(player2Id).get();

      if (!player1Doc.exists || !player2Doc.exists) {
        throw Exception('One or both players not found');
      }

      final player1Data = player1Doc.data()!;
      final player2Data = player2Doc.data()!;

      final player1Mmr = player1Data['mmr'] ?? RankSystem.initialMmr;
      final player2Mmr = player2Data['mmr'] ?? RankSystem.initialMmr;
      final player1RankPoints = player1Data['rankPoints'] ?? 0;
      final player2RankPoints = player2Data['rankPoints'] ?? 0;
      final player1Rank = player1Data['rank'] ?? 'BRONZE';
      final player2Rank = player2Data['rank'] ?? 'BRONZE';
      final player1Division = player1Data['division'] ?? 1;
      final player2Division = player2Data['division'] ?? 1;

      final (player1MmrChange, player2MmrChange) = _calculateMmrChanges(
        player1Mmr,
        player2Mmr,
        isDraw ? null : (winnerId == player1Id),
      );

      final (player1PointChange, player2PointChange) = _calculateRankPointChanges(
        player1Mmr,
        player2Mmr,
        isDraw ? null : (winnerId == player1Id),
      );

      logger.d('MMR Changes - Player1: $player1MmrChange, Player2: $player2MmrChange');
      logger.d('Point Changes - Player1: $player1PointChange, Player2: $player2PointChange');

      if (currentUser.uid == player1Id) {
        final newRankPoints = player1RankPoints + player1PointChange;
        final newMmr = player1Mmr + player1MmrChange;

        final newRank = player1Rank;
        final newDivision = player1Division;

        await _firestore.collection('users').doc(player1Id).update({
          'mmr': newMmr,
          'rankPoints': newRankPoints,
          'lastRankPointsChange': player1PointChange,
          'lastMatchUpdate': FieldValue.serverTimestamp(),
          'rank': newRank,
          'division': newDivision,
          'previousDivision': player1Division != newDivision || player1Rank != newRank
              ? '$player1Rank $player1Division'
              : null,
        });

        logger.i('Updated current user (player1) rank points: $player1PointChange');
      } else if (currentUser.uid == player2Id) {
        final newRankPoints = player2RankPoints + player2PointChange;
        final newMmr = player2Mmr + player2MmrChange;

        final newRank = player2Rank;
        final newDivision = player2Division;

        await _firestore.collection('users').doc(player2Id).update({
          'mmr': newMmr,
          'rankPoints': newRankPoints,
          'lastRankPointsChange': player2PointChange,
          'lastMatchUpdate': FieldValue.serverTimestamp(),
          'rank': newRank,
          'division': newDivision,
          'previousDivision': player2Division != newDivision || player2Rank != newRank
              ? '$player2Rank $player2Division'
              : null,
        });

        logger.i('Updated current user (player2) rank points: $player2PointChange');
      }

      logger.i('Successfully updated rank points for match $matchId');
    } catch (e, stackTrace) {
      logger.e('Error updating rank points:');
      logger.e('Error: $e');
      logger.e('Stack trace: $stackTrace');
      throw Exception('Failed to update rank points: ${e.toString()}');
    }
  }

  // Calculate MMR changes using Elo rating system
  (int, int) _calculateMmrChanges(int player1Mmr, int player2Mmr, bool? player1Won) {
    const kFactor = 32; // Standard K-factor for Elo calculations

    final player1Score = player1Won == null ? 0.5 : (player1Won ? 1.0 : 0.0);
    final player2Score = player1Won == null ? 0.5 : (player1Won ? 0.0 : 1.0);

    final expectedScore1 = 1 / (1 + pow(10, (player2Mmr - player1Mmr) / 400));
    final expectedScore2 = 1 / (1 + pow(10, (player1Mmr - player2Mmr) / 400));

    final player1Change = (kFactor * (player1Score - expectedScore1)).round();
    final player2Change = (kFactor * (player2Score - expectedScore2)).round();

    return (player1Change, player2Change);
  }

  // Calculate rank point changes based on MMR difference and match outcome
  (int, int) _calculateRankPointChanges(int player1Mmr, int player2Mmr, bool? player1Won) {
    const basePoints = 20; // Base points for a win
    final mmrDiff = (player1Mmr - player2Mmr).abs();

    final mmrFactor = max(0.5, min(1.5, 1 + (mmrDiff / 400)));

    if (player1Won == null) {
      return (
        (basePoints * 0.5).round(),
        (basePoints * 0.5).round()
      );
    }

    if (player1Won) {
      final winnerPoints = (basePoints * (player1Mmr < player2Mmr ? mmrFactor : 1/mmrFactor)).round();
      final loserPoints = -(basePoints * 0.5).round();
      return (winnerPoints, loserPoints);
    } else {
      final winnerPoints = (basePoints * (player2Mmr < player1Mmr ? mmrFactor : 1/mmrFactor)).round();
      final loserPoints = -(basePoints * 0.5).round();
      return (loserPoints, winnerPoints);
    }
  }

  // Leave a match
  Future<void> leaveMatch(String matchId) async {
    _matchSubscription?.cancel();

    if (_auth.currentUser == null) {
      return;
    }

    final userId = _auth.currentUser!.uid;
    final matchRef = _activeMatches.doc(matchId);

    try {
      final snapshot = await matchRef.get();

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;

      final player1 = data['player1'] as Map<String, dynamic>?;
      final player2 = data['player2'] as Map<String, dynamic>?;

      if (player1 == null || player2 == null) {
        logger.e('Invalid match data structure');
        return;
      }

      final player1Id = player1['id'] as String?;
      final player2Id = player2['id'] as String?;

      if (player1Id == null || player2Id == null) {
        logger.e('Missing player IDs');
        return;
      }

      if ((player1Id == userId || player2Id == userId) && data['status'] == 'active') {
        final winner = player1Id == userId ? player2['symbol'] as String? : player1['symbol'] as String?;

        if (winner == null) {
          logger.e('Missing player symbols');
          return;
        }

        await matchRef.update({
          'status': 'completed',
          'lastAction': {
            'type': 'player_left',
            'player': userId,
            'timestamp': FieldValue.serverTimestamp(),
          },
          'winner': winner,
          'lastMoveAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
        });

        if (data['isRanked'] == true) {
          Future.delayed(const Duration(milliseconds: 500), () {
            
            _updatePlayerMmr(matchId);
          });
        }
      }
    } catch (e) {
      logger.e('Error leaving match: ${e.toString()}');
    }
  }
}