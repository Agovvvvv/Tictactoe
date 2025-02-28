import 'dart:async';
import '../services/matchmaking_service.dart';
import '../models/match.dart';
import 'game_logic_2players.dart';
import 'package:flutter/material.dart'; // Import necessary package for ValueNotifier

// Add a custom error class for better error handling
class GameLogicException implements Exception {
  final String message;
  GameLogicException(this.message);
  @override
  String toString() => 'GameLogicException: $message';
}

// Add an enum for logging levels
enum LogLevel { debug, info, warning, error }

class GameLogicOnline extends GameLogic {
  final MatchmakingService _matchmakingService;
  StreamSubscription? _matchSubscription;
  final String _localPlayerId;
  GameMatch? _currentMatch;
  
  // Add callbacks for error handling and connection status
  Function(String message)? onError;
  Function(bool isConnected)? onConnectionStatusChanged;
  
  // Add connection status tracking
  bool _isConnected = false;
  Timer? _connectionCheckTimer;
  DateTime? _lastUpdateTime;
  
  // Add a value notifier for the board to enable reactive UI updates
  final ValueNotifier<List<String>> boardNotifier = ValueNotifier<List<String>>(List.filled(9, ''));
  
  // Add a value notifier for the current turn
  final ValueNotifier<String> turnNotifier = ValueNotifier<String>('');
  
  
  
  // Getters
  @override
  String get currentPlayer {
    if (_currentMatch == null) return super.currentPlayer;
    return _currentMatch!.currentTurn;
  }
  
  // Override the board getter to ensure it always returns the latest board state
  @override
  List<String> get board {
    if (_currentMatch == null) return List.filled(9, '');
    return List<String>.from(_currentMatch!.board);
  }
  
  String get opponentName {
    if (_currentMatch == null || _localPlayerId.isEmpty) return 'Opponent';
    final match = _currentMatch!;
    return match.player1.id == _localPlayerId ? match.player2.name : match.player1.name;
  }  
  bool get isLocalPlayerTurn {
    if (_currentMatch == null) return false;
    final symbol = localPlayerSymbol;
    return symbol.isNotEmpty && _currentMatch!.currentTurn == symbol;
  }
  
  bool get isConnected => _isConnected;
  
  String get turnDisplay {
    if (!_isConnected) return 'Connecting...';
    if (_currentMatch == null) return 'Waiting for game...';
    
    // Handle completed games
    if (_currentMatch?.status == 'completed') {
      if (_currentMatch!.winner.isEmpty || _currentMatch!.winner == 'draw') {
        return 'Game Over - Draw!';
      }
      final symbol = localPlayerSymbol;
      return symbol.isNotEmpty && _currentMatch!.winner == symbol ? 'You Won!' : 'Opponent Won!';
    }
    
    // Handle game abandonment
    if (_currentMatch?.status == 'abandoned') {
      return 'Game Abandoned';
    }
    
    // Handle active games
    final symbol = localPlayerSymbol;
    if (symbol.isEmpty) {
      return 'Waiting for game to start...';
    }
    
    // Check whose turn it is
    return isLocalPlayerTurn ? 'Your turn' : 'Opponent\'s turn';
  }
  
  String get localPlayerSymbol {
    if (_currentMatch == null || _localPlayerId.isEmpty) {
      _log('Cannot get local player symbol: match or player ID is null', LogLevel.warning);
      return '';
    }
    
    // Determine player symbol based on ID match
    if (_currentMatch!.player1.id == _localPlayerId) {
      final symbol = _currentMatch!.player1.symbol;
      _log('Local player is Player 1 with symbol: $symbol', LogLevel.debug);
      return symbol;
    }
    if (_currentMatch!.player2.id == _localPlayerId) {
      final symbol = _currentMatch!.player2.symbol;
      _log('Local player is Player 2 with symbol: $symbol', LogLevel.debug);
      return symbol;
    }
    
    _log('Local player ID not found in match players', LogLevel.warning);
    return '';
  }

  bool get isDraw {
    if (_currentMatch == null) return false;
    return _currentMatch!.isDraw;
  }
  
  // Constructor
  GameLogicOnline({
    required Function(String winner) onGameEnd,
    required Function() onPlayerChanged,
    required String localPlayerId,
    this.onError,
    this.onConnectionStatusChanged,
    String? gameId,
  }) : _matchmakingService = MatchmakingService(),
       _localPlayerId = localPlayerId,
       _lastUpdateTime = DateTime.now(),  // Initialize _lastUpdateTime
       super(
         onGameEnd: onGameEnd,
         onPlayerChanged: onPlayerChanged,
         player1Symbol: 'X',  // Local player is always X in online mode
         player2Symbol: 'O',  // Remote player is always O in online mode
         player1GoesFirst: true  // Local player always goes first in online mode
       ) {
    // Start connection monitor
    _startConnectionMonitor();
    
    // Initialize board and turn notifiers
    boardNotifier.value = List.filled(9, '');
    turnNotifier.value = '';
    
    // If a game ID is provided, join that game immediately
    if (gameId != null) {
      joinMatch(gameId);
    }
  }
  
  // Improved logging method with levels
  void _log(String message, LogLevel level) {
    final prefix = switch(level) {
      LogLevel.debug => '[DEBUG]',
      LogLevel.info => '[INFO]',
      LogLevel.warning => '[WARNING]',
      LogLevel.error => '[ERROR]',
    };
    
    // Skip debug logs in production or based on configuration
    bool isDebugMode = true; // This could be a configuration parameter
    
    if (level == LogLevel.debug && !isDebugMode) return;
    
    print('$prefix $message');
  }
  
  // Connection monitoring
  void _startConnectionMonitor() {
    _connectionCheckTimer?.cancel();
    
    // Set initial connection state
    _lastUpdateTime = DateTime.now();
    _isConnected = true;
    onConnectionStatusChanged?.call(true);
    
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Check if we've received updates recently
      if (_lastUpdateTime != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
        if (timeSinceLastUpdate.inSeconds > 15) { // Increased timeout to 15 seconds
          // No recent updates, consider disconnected
          if (_isConnected) {
            _isConnected = false;
            if (onConnectionStatusChanged != null) {
              onConnectionStatusChanged!(false);
            }
            _log('Connection appears to be lost', LogLevel.warning);
            
            // Try to reconnect
            _attemptReconnect();
          }
        } else if (!_isConnected) {
          // We have recent updates but were disconnected
          _isConnected = true;
          if (onConnectionStatusChanged != null) {
            onConnectionStatusChanged!(true);
          }
          _log('Connection restored', LogLevel.info);
        }
      }
    });
  }
  
  // Attempt to reconnect to the match
  Future<void> _attemptReconnect() async {
    if (_currentMatch != null) {
      _log('Attempting to reconnect...', LogLevel.info);
      await joinMatch(_currentMatch!.id);
    }
  }
  
  // Join an existing match
  Future<void> joinMatch(String matchId) async {
    try {
      // Clean up any existing subscriptions
      if (_matchSubscription != null) {
        await _matchSubscription!.cancel();
        _matchSubscription = null;
      }
      
      _log('Setting up match subscription for match ID: $matchId', LogLevel.info);
      // Subscribe to match updates
      _matchSubscription = _matchmakingService.joinMatch(matchId).listen(
        (match) async {
          try {
            // Update connection status
            if (!_isConnected) {
              _isConnected = true;
              if (onConnectionStatusChanged != null) {
                onConnectionStatusChanged!(true);
              }
            }
            _lastUpdateTime = DateTime.now();
            
            _log('=== Match Update ===', LogLevel.debug);
            _log('Status: ${match.status}', LogLevel.debug);
            _log('Current Turn: ${match.currentTurn}', LogLevel.debug);
            _log('Board: ${match.board}', LogLevel.debug);
            _log('Player 1: ${match.player1.name} (${match.player1.symbol})', LogLevel.debug);
            _log('Player 2: ${match.player2.name} (${match.player2.symbol})', LogLevel.debug);
            
            final previousMatch = _currentMatch;
            _currentMatch = match;
            
            // Get local player info
            final symbol = localPlayerSymbol;
            _log('Local Player Info:', LogLevel.debug);
            _log('ID: $_localPlayerId', LogLevel.debug);
            _log('Symbol: $symbol', LogLevel.debug);
            _log('Is my turn: ${isLocalPlayerTurn}', LogLevel.debug);
            
            // Track new moves
            List<String> oldBoard = boardNotifier.value;
            List<String> newBoard = List<String>.from(match.board);
            
            for (int i = 0; i < newBoard.length; i++) {
              if (newBoard[i].isNotEmpty && oldBoard[i].isEmpty) {
                if (newBoard[i] == 'X') {
                  xMoves.add(i);
                  xMoveCount++;
                  if (xMoveCount >= 4 && xMoves.length > 3) {
                    newBoard[xMoves.removeAt(0)] = '';
                  }
                } else if (newBoard[i] == 'O') {
                  oMoves.add(i);
                  oMoveCount++;
                  if (oMoveCount >= 4 && oMoves.length > 3) {
                    newBoard[oMoves.removeAt(0)] = '';
                  }
                }
              }
            }
            
            // Update board notifier and turn notifier
            boardNotifier.value = newBoard;
            turnNotifier.value = match.currentTurn;
            
            // Update connection status
            _lastUpdateTime = DateTime.now();
            if (!_isConnected) {
              _isConnected = true;
              if (onConnectionStatusChanged != null) {
                onConnectionStatusChanged!(true);
              }
            }
            
            _log('Updating UI...', LogLevel.debug);

            // Handle initialization issues
            if (match.status == 'waiting' || match.status == 'pending') {
              _log('Game not yet active - waiting for initialization', LogLevel.info);
              return;
            }
            
            // Verify player assignment
            if (symbol.isEmpty && match.status == 'active') {
              _log('ERROR: Player symbol not assigned in active game', LogLevel.error);
              if (_localPlayerId == match.player1.id || _localPlayerId == match.player2.id) {
                _log('Attempting to recover game state...', LogLevel.info);
                await Future.delayed(const Duration(milliseconds: 500));
                await _matchmakingService.makeMove(match.id, -1);
                return;
              } else {
                _log('Local player not found in match - cannot recover', LogLevel.error);
                if (onError != null) {
            onError!('You are not a participant in this game');
          }
                return;
              }
            }
            
            // Handle game completion
            if (match.status == 'completed') {
              _log('Game Completion Check:', LogLevel.debug);
              
              // Handle invalid completion state
              if (match.board.every((cell) => cell.isEmpty)) {
                _log('Invalid completion state detected - resetting game', LogLevel.warning);
                await _matchmakingService.makeMove(match.id, -1);
                return;
              }
              
              // Trigger game end events only once
              if (previousMatch?.status != 'completed') {
                if (match.winner.isNotEmpty && match.winner != 'draw') {
                  _log('Game Won! Winner: ${match.winner}', LogLevel.info);
                  onGameEnd.call(match.winner);
                } else if (match.board.every((cell) => cell.isNotEmpty)) {
                  _log('Game Draw!', LogLevel.info);
                  onGameEnd.call('draw');
                }
              }
            }
            
            // Handle game abandonment
            if (match.status == 'abandoned' && previousMatch?.status != 'abandoned') {
              _log('Game was abandoned', LogLevel.info);
              onError?.call('Opponent left the game');
              onGameEnd.call('abandoned');
            }
            
            // Update UI
            _log('Updating UI...', LogLevel.debug);
            onPlayerChanged?.call();
            
          } catch (e, stackTrace) {
            _log('Error in match update handler:', LogLevel.error);
            _log('Error: $e', LogLevel.error);
            _log('Stack trace: $stackTrace', LogLevel.error);
            if (onError != null) {
            onError!('Error updating game state');
          }
          }
        },
        onError: (error, stackTrace) {
          _log('Error in match subscription:', LogLevel.error);
          _log('Error: $error', LogLevel.error);
          _log('Stack trace: $stackTrace', LogLevel.error);
          
          // Update connection status
          _isConnected = false;
          onConnectionStatusChanged?.call(false);
          if (onError != null) {
            onError!('Connection error occurred');
          }
        },
      );
    } catch (e) {
      _log('Error joining match: $e', LogLevel.error);
      if (onError != null) {
        onError!('Failed to join game');
      }
    }
  }
  
  /// Get the index of the next symbol that will vanish
  @override
  int? getNextToVanish() {
    if (currentPlayer == 'X' && xMoveCount >= 3 && xMoves.isNotEmpty) {
      return xMoves[0];
    } else if (currentPlayer == 'O' && oMoveCount >= 3 && oMoves.isNotEmpty) {
      return oMoves[0];
    }
    return null;
  }

  // Improved validation logic for making moves
  bool _validateMove(GameMatch match, int index) {
    // Validate game is active
    if (match.status != 'active') {
      _log('Game is not active (status: ${match.status})', LogLevel.warning);
      onError?.call('Game is not active');
      return false;
    }
    
    // Validate player symbol and turn
    final currentSymbol = localPlayerSymbol;
    if (currentSymbol.isEmpty) {
      _log('Local player symbol not found', LogLevel.warning);
      onError?.call('Unable to determine your player');
      return false;
    }
    
    if (match.currentTurn != currentSymbol) {
      _log('Not your turn (current: ${match.currentTurn}, yours: $currentSymbol)', LogLevel.warning);
      onError?.call('Not your turn');
      return false;
    }
    
    // Validate position
    if (index < 0 || index >= 9) {
      _log('Invalid position: $index', LogLevel.warning);
      onError?.call('Invalid move position');
      return false;
    }
    
    // Check if position is already taken
    if (match.board[index].isNotEmpty) {
      _log('Position $index already taken with ${match.board[index]}', LogLevel.warning);
      onError?.call('This position is already taken');
      return false;
    }
    
    return true;
  }
  
  // Make a move with improved error handling and atomic validation
  @override
  Future<void> makeMove(int index) async {
    if (!_isConnected) {
      if (onError != null) {
        onError!('No connection to the game server');
      }
      return;
    }
    
    if (_currentMatch == null) {
      _log('Cannot make move: No active match', LogLevel.warning);
      if (onError != null) {
        onError!('No active game');
      }
      return;
    }
    
    // Create a local copy to prevent race conditions
    final matchSnapshot = _currentMatch!;
    
    // Perform validation in a single method for cleaner code
    if (!_validateMove(matchSnapshot, index)) {
      return;
    }
    
    _log('Making move: Position=$index, Symbol=${localPlayerSymbol}', LogLevel.info);
    
    try {
      // Make the move in Firestore with retry logic
      await _tryWithRetry(() => _matchmakingService.makeMove(matchSnapshot.id, index));
      _log('Move successfully made', LogLevel.info);
    } catch (e) {
      _log('Error making move: $e', LogLevel.error);
      if (onError != null) {
        onError!('Failed to submit your move');
      }
    }
  }
  
  // Retry logic for network operations
  Future<T> _tryWithRetry<T>(Future<T> Function() operation, {int maxRetries = 2}) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxRetries) {
          _log('Operation failed after $attempts attempts: $e', LogLevel.error);
          rethrow;
        }
        _log('Retrying operation (attempt $attempts): $e', LogLevel.warning);
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
  }
  
  
  void dispose() {
    if (_connectionCheckTimer != null) {
      _connectionCheckTimer!.cancel();
    }
    if (_matchSubscription != null) {
      _matchSubscription!.cancel();
    }
    _matchmakingService.dispose();
    _log('Game logic resources disposed', LogLevel.info);
  }
}