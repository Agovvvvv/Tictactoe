import 'game_logic_2players.dart';
import 'computer_player.dart';
import 'package:flutter/foundation.dart';

class GameLogicVsComputer extends GameLogic {
  final ValueNotifier<List<String>> boardNotifier = ValueNotifier<List<String>>(['', '', '', '', '', '', '', '', '']);
  final ComputerPlayer computerPlayer;
  bool isComputerTurn = false;

  GameLogicVsComputer({
    required super.onGameEnd,
    super.onPlayerChanged,
    required this.computerPlayer,
    required String humanSymbol,
  }) : super(
    player1Symbol: humanSymbol,
    player2Symbol: humanSymbol == 'X' ? 'O' : 'X',
  ) {
    currentPlayer = player1Symbol;
  }

  void _checkAndNotifyGameEnd() {
    final winner = checkWinner();
    if (winner.isNotEmpty || xMoveCount + oMoveCount == 30) {
      onGameEnd(winner);
    }
  }


  void _processMove(int index, bool isHumanMove) {
    try {
      // Make the move
      board[index] = currentPlayer;
      boardNotifier.value = List<String>.from(board);
      onPlayerChanged?.call(); // Update UI to show the move

      // Track move
      if (isHumanMove) {
        xMoves.add(index);
        xMoveCount++;
      } else {
        oMoves.add(index);
        oMoveCount++;
      }

      // Check for win before vanishing effect
      final winner = checkWinner();
      if (winner.isNotEmpty || xMoveCount + oMoveCount == 30) {
        _checkAndNotifyGameEnd();
        return;
      }

      // Only apply vanishing effect if no win
      final moves = isHumanMove ? xMoves : oMoves;
      final moveCount = isHumanMove ? xMoveCount : oMoveCount;
      if (moveCount >= 4 && moves.length > 3) {
        final vanishIndex = moves.removeAt(0);
        board[vanishIndex] = '';
        boardNotifier.value = List<String>.from(board);
        onPlayerChanged?.call(); // Update UI after vanishing
      }

      // Switch players
      currentPlayer = isHumanMove ? player2Symbol : player1Symbol;
      isComputerTurn = isHumanMove;
      onPlayerChanged?.call(); // Update UI for turn change
    } catch (e) {
      // If any error occurs during processing, ensure game state is consistent
      if (!isHumanMove) {
        isComputerTurn = false;
      }
    }
  }

  @override
  void makeMove(int index) {
    // Only allow moves on empty cells during human's turn
    if (isComputerTurn || board[index].isNotEmpty) {
      return;
    }

    // Process human move
    _processMove(index, true);

    // If game ended after human move, don't make computer move
    final winner = checkWinner();
    if (winner.isNotEmpty || xMoveCount + oMoveCount == 30) {
      return;
    }

    // Make computer move after delay
    isComputerTurn = true; // Set computer's turn
    Future.delayed(Duration(milliseconds: 500), () async {
      try {
        // Get computer's move
        final move = await computerPlayer.getMove(List<String>.from(board));
        
        // Make the move and check for game end
        if (board[move].isEmpty) {
          _processMove(move, false);
        }
      } catch (e) {
        print('Error in computer move: $e');
        isComputerTurn = false;
      }
    });
    }
  
  
  

  @override
  void resetGame() {
    super.resetGame();
    isComputerTurn = false;
    currentPlayer = player1Symbol;
    boardNotifier.value = List<String>.from(board);
  }
}
