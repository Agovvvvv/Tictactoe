import '../models/utils/logger.dart';

/// GameLogic class for handling two-player Tic Tac Toe game
class GameLogic {
  /// Game board represented as a list of strings ('X', 'O', or empty)
  List<String> board = List.filled(9, '', growable: false);
  
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
    // Set the starting player based on who goes first and their symbol
    // If O goes first, we want O to be currentPlayer regardless of which player has O
    currentPlayer = _player1GoesFirst ? player1Symbol : player2Symbol;
    logger.i('GameLogic initialized - Player1: $player1Symbol, Player2: $player2Symbol, First: $currentPlayer');
  }

  /// Process a move for the current player at the specified index
  void makeMove(int index) {
    // Only allow moves on empty cells
    if (board[index].isNotEmpty) return;

    // Place symbol
    board[index] = currentPlayer;
    
    // Update move tracking
    if (currentPlayer == 'X') {
      xMoves.add(index);
      xMoveCount++;
    } else {
      oMoves.add(index);
      oMoveCount++;
    }
    
    // Update UI
    onPlayerChanged?.call();

    // Check for win before applying vanishing effect
    String winner = checkWinner();
    if (winner.isNotEmpty) {
      onGameEnd(winner);
      return;
    }

    // Only apply vanishing effect if there's no win
    if (currentPlayer == 'X' && xMoveCount >= 4 && xMoves.length > 3) {
      board[xMoves.removeAt(0)] = '';
      onPlayerChanged?.call();
    } else if (currentPlayer == 'O' && oMoveCount >= 4 && oMoves.length > 3) {
      board[oMoves.removeAt(0)] = '';
      onPlayerChanged?.call();
    }

    // Check for draw
    if (xMoveCount + oMoveCount == 30) {
      onGameEnd('');
      return;
    }

    // Switch turns
    currentPlayer = currentPlayer == player1Symbol ? player2Symbol : player1Symbol;
    onPlayerChanged?.call();
  }

  /// Check for a winner using predefined win patterns
  String checkWinner() {
    const winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],  // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8],  // Columns
      [0, 4, 8], [2, 4, 6]              // Diagonals
    ];
    
    for (var pattern in winPatterns) {
      if (board[pattern[0]].isNotEmpty &&
          board[pattern[0]] == board[pattern[1]] &&
          board[pattern[1]] == board[pattern[2]]) {
        return board[pattern[0]];
      }
    }
    return '';
  }

  /// Get the index of the next symbol that will vanish
  int? getNextToVanish() {
    if (currentPlayer == 'X' && xMoves.isNotEmpty && xMoveCount > 2) {
      return xMoves[0];
    } else if (currentPlayer == 'O' && oMoves.isNotEmpty && oMoveCount > 2) {
      return oMoves[0];
    }
    return null;
  }

  /// Reset the game to its initial state
  void resetGame() {
    board = List.filled(9, '');
    xMoves.clear();
    oMoves.clear();
    xMoveCount = 0;
    oMoveCount = 0;
    // Reset to the correct starting player based on who goes first
    currentPlayer = _player1GoesFirst ? player1Symbol : player2Symbol;
    // Reset to initial state
  }
}
