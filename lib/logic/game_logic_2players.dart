import 'package:flutter/foundation.dart';
import '../models/utils/logger.dart';
import '../models/utils/win_checker.dart';

/// GameLogic class for handling two-player Tic Tac Toe game
class GameLogic {
  /// Game board represented as a list of strings ('X', 'O', or empty)
  final List<String> board = List.filled(9, '', growable: false);
  
  /// ValueNotifier to notify listeners of board changes
  late final ValueNotifier<List<String>> boardNotifier;

  /// List to track X's moves in order
  List<int> xMoves = [];
  
  /// List to track O's moves in order
  List<int> oMoves = [];
  
  /// Current player's symbol ('X' or 'O')
  late String currentPlayer;
  
  /// Symbol for player 1 (default 'X')
  late final String player1Symbol;
  
  /// Symbol for player 2 (default 'O')
  late final String player2Symbol;
  
  /// Counter for X's total moves
  int xMoveCount = 0;
  
  /// Counter for O's total moves
  int oMoveCount = 0;
  
  /// Callback function when game ends
  final Function(String) onGameEnd;
  
  /// Callback function when player changes
  final Function()? onPlayerChanged;

  /// Store who goes first
  final bool _player1GoesFirst;

  GameLogic({
    required this.onGameEnd,
    required this.player1Symbol,
    required this.player2Symbol,
    this.onPlayerChanged,
    bool player1GoesFirst = true,
  }) : _player1GoesFirst = player1GoesFirst {
    boardNotifier = ValueNotifier<List<String>>(List.from(board));
    currentPlayer = _player1GoesFirst ? player1Symbol : player2Symbol;
    logger.i('GameLogic initialized - Player1: $player1Symbol, Player2: $player2Symbol, First: $currentPlayer');
  }

  void makeMove(int index) {
    if (board[index].isEmpty) {
      // Update the board
      board[index] = currentPlayer;
      boardNotifier.value = List.from(board); // Notify listeners of board change

      // Update move history
      if (currentPlayer == 'X') {
        xMoves.add(index);
        xMoveCount++;
      } else {
        oMoves.add(index);
        oMoveCount++;
      }

      int? nextToVanish;
      logger.i('xMovesCount: ${xMoveCount}, oMovesCount: ${oMoveCount}');
      if ((xMoveCount + oMoveCount) > 6) {
        nextToVanish = getNextToVanish();
        if (nextToVanish != null) {
          board[nextToVanish] = ''; // Remove the symbol
          boardNotifier.value = List.from(board); // Notify listeners of board change
          if (currentPlayer == 'X') {
            xMoves.removeAt(0); // Remove the oldest X move
          } else {
            oMoves.removeAt(0); // Remove the oldest O move
          }
        }
      }

      if (xMoveCount + oMoveCount > 3) {
        final winner = checkWinner(nextToVanish);
        if (winner.isNotEmpty) {
          onGameEnd(winner);
        }
      }
      // Switch turns
      currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
      onPlayerChanged!();
    }
  }

  String checkWinner([int? nextToVanish]) {
    if (WinChecker.checkWin(board, 'X', nextToVanish: nextToVanish)) {
      return 'X';
    }
    if (WinChecker.checkWin(board, 'O', nextToVanish: nextToVanish)) {
      return 'O';
    }
    if (!board.contains('')) {
      return 'draw';
    }
    return '';
  }

  int? getNextToVanish() {
    if (currentPlayer == 'X' && xMoves.isNotEmpty) {
      return xMoves[0];
    } else if (currentPlayer == 'O' && oMoves.isNotEmpty) {
      return oMoves[0];
    }
    return null;
  }

  /// Reset the game to its initial state
  void resetGame() {
    board.fillRange(0, 9, '');
    boardNotifier.value = List.from(board); // Notify listeners of board change
    xMoves.clear();
    oMoves.clear();
    xMoveCount = 0;
    oMoveCount = 0;
    currentPlayer = _player1GoesFirst ? player1Symbol : player2Symbol;
  }

  // Dispose of the ValueNotifier when the GameLogic is disposed
  void dispose() {
    boardNotifier.dispose();
  }
}