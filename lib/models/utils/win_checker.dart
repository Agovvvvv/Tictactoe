class WinChecker {
  /// Checks if the given [symbol] has won the game.
  /// [board] is the current state of the board.
  /// [symbol] is the player's symbol ('X' or 'O').
  /// [nextToVanish] is the index of the next symbol to vanish (if any).
  static bool checkWin(List<String> board, String symbol, {int? nextToVanish}) {
    final winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
      [0, 4, 8], [2, 4, 6]             // diagonals
    ];

    for (final pattern in winPatterns) {
      // Check if all cells in the pattern match the symbol
      if (board[pattern[0]] == symbol &&
          board[pattern[1]] == symbol &&
          board[pattern[2]] == symbol) {
        // If a cell in the pattern is about to vanish, ignore this pattern
        if (nextToVanish != null &&
            (pattern[0] == nextToVanish ||
             pattern[1] == nextToVanish ||
             pattern[2] == nextToVanish)) {
          continue; // Skip this pattern
        }
        return true; // Winning pattern found
      }
    }
    return false; // No winning pattern found
  }
}