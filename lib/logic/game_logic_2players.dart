/// GameLogic class for handling two-player Tic Tac Toe game
class GameLogic {
  /// Game board represented as a list of strings ('X', 'O', or empty)
  List<String> _board = List.filled(9, '', growable: false);
  
  /// Get the current board state
  List<String> get board => _board;
  
  /// Set the board state
  set board(List<String> newBoard) {
    _board = newBoard;
  }
  
  /// List to track X's moves in order
  List<int> xMoves = [];
  
  /// List to track O's moves in order
  List<int> oMoves = [];
  
  /// Current player's symbol ('X' or 'O')
  late String currentPlayer;
  
  /// Symbol for player 1 (default 'X')
  final String player1Symbol;
  
  /// Symbol for player 2 (default 'O')
  final String player2Symbol;
  
  /// Counter for X's total moves
  int xMoveCount = 0;
  
  /// Counter for O's total moves
  int oMoveCount = 0;
  
  /// Callback function when game ends
  final Function(String) onGameEnd;
  
  /// Callback function when player changes
  final Function()? onPlayerChanged;

  GameLogic({
    required this.onGameEnd,
    this.player1Symbol = 'X',
    this.player2Symbol = 'O',
    this.onPlayerChanged,
  }) {
    currentPlayer = player1Symbol;
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
    currentPlayer = player1Symbol;
  }
}
