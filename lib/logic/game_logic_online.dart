import 'dart:async';
import '../services/matches/matchmaking_service.dart';
import '../models/match.dart';
import 'game_logic_2players.dart';
import 'package:flutter/material.dart'; // Import necessary package for ValueNotifier
import '../models/utils/logger.dart';
import '../models/utils/win_checker.dart'; // Utility for win condition checking
import '../models/utils/move_validator.dart'; // Utility for move validation
import '../models/utils/error_handler.dart'; // Utility for error handling

class GameLogicOnline extends GameLogic {
  final MatchmakingService _matchmakingService;
  StreamSubscription? _matchSubscription;
  final String _localPlayerId;
  GameMatch? _currentMatch;

  // Flag to track if we've already called onGameEnd
  bool _gameEndCalled = false;

  // Callbacks for error handling and connection status
  Function(String message)? onError;
  Function(bool isConnected)? onConnectionStatusChanged;

  // Connection status tracking
  bool _isConnected = false;
  Timer? _connectionCheckTimer;
  DateTime? _lastUpdateTime;

  // Value notifiers for reactive UI updates
  final ValueNotifier<List<String>> boardNotifier = ValueNotifier<List<String>>(List.filled(9, ''));
  final ValueNotifier<String> turnNotifier = ValueNotifier<String>('');

  // Getters
  @override
  String get currentPlayer => _currentMatch?.currentTurn ?? super.currentPlayer;
  String get localPlayerId => _localPlayerId;
  GameMatch? get currentMatch => _currentMatch;

  @override
  List<String> get board => _currentMatch?.board ?? List.filled(9, '');

  String get opponentName {
    if (_currentMatch == null || _localPlayerId.isEmpty) return 'Opponent';
    final match = _currentMatch!;
    return match.player1.id == _localPlayerId ? match.player2.name : match.player1.name;
  }

  bool get isLocalPlayerTurn {
    if (_currentMatch == null) return false;
    return localPlayerSymbol.isNotEmpty && _currentMatch!.currentTurn == localPlayerSymbol;
  }

  bool get isConnected => _isConnected;

  String get turnDisplay {
    if (!_isConnected) return 'Connecting...';
    if (_currentMatch == null) return 'Waiting for game...';

    if (_currentMatch?.status == 'completed') {
      if (_currentMatch!.winner.isEmpty || _currentMatch!.winner == 'draw') {
        return 'Game Over - Draw!';
      }
      return _currentMatch!.winner == localPlayerSymbol ? 'You Won!' : 'Opponent Won!';
    }

    if (_currentMatch?.status == 'abandoned') return 'Game Abandoned';
    if (localPlayerSymbol.isEmpty) return 'Waiting for game to start...';
    return isLocalPlayerTurn ? 'Your turn' : 'Opponent\'s turn';
  }

  String get localPlayerSymbol {
    if (_currentMatch == null || _localPlayerId.isEmpty) {
      logger.w('Cannot get local player symbol: match or player ID is null');
      return '';
    }
    if (_currentMatch!.player1.id == _localPlayerId) return _currentMatch!.player1.symbol;
    if (_currentMatch!.player2.id == _localPlayerId) return _currentMatch!.player2.symbol;
    logger.w('Local player ID not found in match players');
    return '';
  }

  bool get isDraw => _currentMatch?.isDraw ?? false;

  // Constructor
  GameLogicOnline({
    required super.onGameEnd,
    required Function() super.onPlayerChanged,
    required String localPlayerId,
    this.onError,
    this.onConnectionStatusChanged,
    String? gameId,
  }) : _matchmakingService = MatchmakingService(),
       _localPlayerId = localPlayerId,
       _lastUpdateTime = DateTime.now(),
       super(
         player1Symbol: 'X',
         player2Symbol: 'O',
         player1GoesFirst: true,
       ) {
    _startConnectionMonitor();
    boardNotifier.value = List.filled(9, '');
    turnNotifier.value = '';

    if (gameId != null) joinMatch(gameId);
  }

  // Connection monitoring
  void _startConnectionMonitor() {
    _connectionCheckTimer?.cancel();
    _lastUpdateTime = DateTime.now();
    _isConnected = true;
    onConnectionStatusChanged?.call(true);

    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
      if (timeSinceLastUpdate.inSeconds > 15) {
        if (_isConnected) {
          _isConnected = false;
          onConnectionStatusChanged?.call(false);
          logger.w('Connection appears to be lost');
          _attemptReconnect();
        }
      } else if (!_isConnected) {
        _isConnected = true;
        onConnectionStatusChanged?.call(true);
        logger.i('Connection restored');
      }
    });
  }

  // Attempt to reconnect to the match
  Future<void> _attemptReconnect() async {
    if (_currentMatch != null) {
      logger.i('Attempting to reconnect...');
      await joinMatch(_currentMatch!.id);
    }
  }

  // Join an existing match
  Future<void> joinMatch(String matchId) async {
    try {
      if (_matchSubscription != null) await _matchSubscription!.cancel();
      _matchSubscription = _matchmakingService.joinMatch(matchId).listen(
        (match) async {
          try {
            if (!_isConnected) {
              _isConnected = true;
              onConnectionStatusChanged?.call(true);
            }
            _lastUpdateTime = DateTime.now();

            final previousMatch = _currentMatch;
            _currentMatch = match;

            // Check for win condition
            final hasWinner = WinChecker.checkWin(match.board, match.currentTurn);

            if (hasWinner || match.status == 'completed') {
              if (match.status == 'completed' && match.board.every((cell) => cell.isEmpty)) {
                logger.w('Match marked as completed with empty board - likely an error');
                try {
                  await _matchmakingService.makeMove(match.id, -1);
                  logger.i('Attempted to reset match to active state');
                  return;
                } catch (e) {
                  logger.e('Failed to reset match: $e');
                }
              }

              if (!_gameEndCalled) {
                _gameEndCalled = true;
                onGameEnd(match.winner);
              }

              boardNotifier.value = match.board;
              turnNotifier.value = match.currentTurn;
              onPlayerChanged?.call();
              return;
            }

            // Update board and turn notifiers
            boardNotifier.value = match.board;
            turnNotifier.value = match.currentTurn;

            // Handle game completion or abandonment
            if (match.status == 'completed' && previousMatch?.status != 'completed' && !_gameEndCalled) {
              _gameEndCalled = true;
              onGameEnd(match.winner);
            } else if (match.status == 'abandoned' && previousMatch?.status != 'abandoned' && !_gameEndCalled) {
              _gameEndCalled = true;
              onError?.call('Opponent left the game');
              onGameEnd('abandoned');
            }

            onPlayerChanged?.call();
          } catch (e, stackTrace) {
            ErrorHandler.handleError('Error in match update handler: $e', onError: onError);
            logger.e('Stack trace: $stackTrace');
          }
        },
        onError: (error, stackTrace) {
          ErrorHandler.handleError('Error in match subscription: $error', onError: onError);
          logger.e('Stack trace: $stackTrace');
          _isConnected = false;
          onConnectionStatusChanged?.call(false);
        },
      );
    } catch (e) {
      ErrorHandler.handleError('Error joining match: $e', onError: onError);
    }
  }

  // Make a move
  @override
  Future<void> makeMove(int index) async {
    if (!_isConnected) {
      ErrorHandler.handleError('No connection to the game server', onError: onError);
      return;
    }

    if (_currentMatch == null) {
      ErrorHandler.handleError('No active game', onError: onError);
      return;
    }

    final matchSnapshot = _currentMatch!;

    if (matchSnapshot.status == 'completed') {
      if (!_gameEndCalled) {
        _gameEndCalled = true;
        onGameEnd(matchSnapshot.winner);
      }
      return;
    }

    if (!MoveValidator.validateMove(matchSnapshot, index, localPlayerSymbol)) {
      return;
    }

    try {
      await _matchmakingService.makeMove(matchSnapshot.id, index);
    } catch (e) {
      ErrorHandler.handleError('Failed to submit your move: $e', onError: onError);
    }
  }

  // Dispose resources
  void dispose() {
    _gameEndCalled = false;
    _connectionCheckTimer?.cancel();
    _matchSubscription?.cancel();
    _currentMatch = null;
    boardNotifier.value = List.filled(9, '');
    turnNotifier.value = '';
    _isConnected = false;
    _matchmakingService.dispose();
    logger.i('Game logic resources disposed');
  }
}