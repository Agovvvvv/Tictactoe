import '../models/player.dart';

/// Represents the difficulty level of the computer player.
/// Each level implements a different strategy for move selection.
enum GameDifficulty {
  /// Makes completely random moves
  easy,
  
  /// Makes random moves 70% of the time, perfect moves 30%
  medium,
  
  /// Makes random moves 30% of the time, perfect moves 70%
  hard,
  
}

/// A computer player that can make moves in the game with varying levels of difficulty.
/// Uses different strategies based on the selected difficulty level.
class ComputerPlayer extends Player {
  /// The difficulty level that determines the computer's playing strategy
  final GameDifficulty difficulty;
  
  /// The symbol (X or O) used by the computer player
  final String computerSymbol;
  
  /// The symbol (X or O) used by the human player
  final String playerSymbol;

  /// Creates a computer player with the specified difficulty and symbols.
  /// 
  /// [difficulty] determines how the computer will play
  /// [computerSymbol] is the symbol (X or O) used by the computer
  /// [playerSymbol] is the symbol (X or O) used by the human player
  ComputerPlayer({
    required this.difficulty,
    required this.computerSymbol,
    required this.playerSymbol,
    required super.name,
  }) : super(symbol: computerSymbol);

  /// Gets the computer's next move based on the current board state and difficulty level.
  /// 
  /// [board] is the current game board state
  /// Returns the index where the computer will place its symbol
  /// Throws [StateError] if there are no valid moves available
  Future<int> getMove(List<String> board) async {
    if (!board.contains('')) {
      throw StateError('No valid moves available: board is full');
    }

    // Add delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));
    return _getBestMove(board);
  }

  /// Determines the best move based on the current difficulty level
  int _getBestMove(List<String> board) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return _getRandomMove(board);
      case GameDifficulty.medium:
        return _getMediumMove(board);
      case GameDifficulty.hard:
        return _getHardMove(board);
    }
  }

  /// Makes a completely random move from the available positions
  int _getRandomMove(List<String> board) {
    final List<int> availableMoves = _getAvailableMoves(board);
    if (availableMoves.isEmpty) {
      throw StateError('No valid moves available');
    }
    availableMoves.shuffle();
    return availableMoves.first;
  }

  /// Gets a list of all empty positions on the board
  List<int> _getAvailableMoves(List<String> board) {
    final List<int> moves = [];
    for (int i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        moves.add(i);
      }
    }
    return moves;
  }

  /// Makes a strategic move with medium difficulty
  /// - Blocks opponent's winning moves
  /// - Takes winning moves when available
  /// - Otherwise makes a random move
  int _getMediumMove(List<String> board) {
    // First, check if we can win in the next move
    final winningMove = _findWinningMove(board, computerSymbol);
    if (winningMove != -1) return winningMove;

    // Then, check if we need to block opponent's winning move
    final blockingMove = _findWinningMove(board, playerSymbol);
    if (blockingMove != -1) return blockingMove;

    // Otherwise make a random move
    return _getRandomMove(board);
  }

  /// Makes a strategic move with hard difficulty
  /// - Always takes winning moves
  /// - Always blocks opponent's winning moves
  /// - Usually makes the optimal move
  /// - Occasionally makes a suboptimal move to be beatable
  int _getHardMove(List<String> board) {
    // First, check if we can win in the next move
    final winningMove = _findWinningMove(board, computerSymbol);
    if (winningMove != -1) return winningMove;

    // Then, check if we need to block opponent's winning move
    final blockingMove = _findWinningMove(board, playerSymbol);
    if (blockingMove != -1) return blockingMove;

    // 20% chance of making a strategic but not perfect move
    return _getStrategicMove(board);
  }

  /// Finds a winning move for the given symbol if one exists
  /// Returns -1 if no winning move is available
  int _findWinningMove(List<String> board, String symbol) {
    final winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
      [0, 4, 8], [2, 4, 6]             // Diagonals
    ];

    // Check each pattern for a potential winning move
    for (final pattern in winPatterns) {
      final p1 = board[pattern[0]];
      final p2 = board[pattern[1]];
      final p3 = board[pattern[2]];
      
      // If two positions have our symbol and one is empty, that's a winning move
      if (p1 == symbol && p2 == symbol && p3.isEmpty) return pattern[2];
      if (p1 == symbol && p3 == symbol && p2.isEmpty) return pattern[1];
      if (p2 == symbol && p3 == symbol && p1.isEmpty) return pattern[0];
    }
    return -1;
  }

  /// Makes a strategic move that prioritizes center and corners
  int _getStrategicMove(List<String> board) {
    // Try to take center if available
    if (board[4].isEmpty) return 4;
    
    // Try to take a corner
    final corners = [0, 2, 6, 8];
    corners.shuffle();
    for (final corner in corners) {
      if (board[corner].isEmpty) return corner;
    }
    
    // Take any available edge
    final edges = [1, 3, 5, 7];
    edges.shuffle();
    for (final edge in edges) {
      if (board[edge].isEmpty) return edge;
    }
    
    // Fallback to random move
    return _getRandomMove(board);
  }

  
}
