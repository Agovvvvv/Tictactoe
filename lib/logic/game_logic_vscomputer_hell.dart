import 'game_logic_2players.dart';
import 'computer_player.dart';
import 'package:flutter/foundation.dart';
import '../models/utils/logger.dart';

/// Specialized game logic for playing against a computer in Hell Mode
class GameLogicVsComputerHell extends GameLogic {
  final ValueNotifier<List<String>> boardNotifier = ValueNotifier<List<String>>(List.filled(9, ''));
  final ComputerPlayer computerPlayer;
  bool isComputerTurn = false;

  GameLogicVsComputerHell({
    required super.onGameEnd,
    super.onPlayerChanged,
    required this.computerPlayer,
    required String humanSymbol,
  }) : super(
    player1Symbol: humanSymbol,
    player2Symbol: humanSymbol == 'X' ? 'O' : 'X',
  ) {
    currentPlayer = player1Symbol;
    boardNotifier.value = List<String>.from(board);
    logger.i('GameLogicVsComputerHell initialized: humanSymbol=$humanSymbol, currentPlayer=$currentPlayer');
  }

  void checkAndNotifyGameEnd() {
    final winner = checkWinner();
    logger.i('checkAndNotifyGameEnd: Checking for winner: $winner');
    
    if (winner.isNotEmpty || xMoveCount + oMoveCount == 30) {
      logger.i(winner.isNotEmpty ? 'checkAndNotifyGameEnd: Winner detected: $winner' : 'checkAndNotifyGameEnd: Draw detected');
      Future.delayed(Duration(milliseconds: 100), () => onGameEnd(winner.isNotEmpty ? winner : 'draw'));
    }
  }


  void processMove(int index, bool isHumanMove) {
    try {
      if (index < 0 || index >= board.length || board[index].isNotEmpty) {
        logger.e(index < 0 || index >= board.length ? 'Invalid move index: $index' : 'Cell already occupied at index: $index');
        return;
      }
      
      if ((isHumanMove && isComputerTurn) || (!isHumanMove && !isComputerTurn)) {
        logger.e(isHumanMove ? 'Attempted human move during computer turn' : 'Attempted computer move during human turn');
        return;
      }
      
      board[index] = isHumanMove ? player1Symbol : player2Symbol;
      boardNotifier.value = List<String>.from(board);

      if (isHumanMove) {
        xMoves.add(index);
        xMoveCount++;
      } else {
        oMoves.add(index);
        oMoveCount++;
      }

      final winner = checkWinner();
      logger.i('processMove: Move at $index by ${isHumanMove ? "human" : "computer"}, winner check: $winner');
      
      checkAndNotifyGameEnd();

      if ((isHumanMove ? xMoveCount : oMoveCount) >= 4 && (isHumanMove ? xMoves : oMoves).length > 3) {
        final vanishIndex = (isHumanMove ? xMoves : oMoves).removeAt(0);
        board[vanishIndex] = '';
        boardNotifier.value = List<String>.from(board);
        onPlayerChanged?.call();
      }

      currentPlayer = isHumanMove ? player2Symbol : player1Symbol;
      isComputerTurn = isHumanMove;
      logger.i('Turn switched: currentPlayer=$currentPlayer, isComputerTurn=$isComputerTurn');
      onPlayerChanged?.call();
    } catch (e) {
      logger.e('Error in processMove: $e');
      isComputerTurn = !isHumanMove;
      currentPlayer = isHumanMove ? player2Symbol : player1Symbol;
      logger.i('Error recovery: Reset to currentPlayer=$currentPlayer, isComputerTurn=$isComputerTurn');
      onPlayerChanged?.call();
    }
  }

  @override
  void makeMove(int index) {
    logger.i('GameLogicVsComputerHell.makeMove called for index $index, isComputerTurn=$isComputerTurn, currentPlayer=$currentPlayer');
    
    if (isComputerTurn || board[index].isNotEmpty) {
      logger.i('GameLogicVsComputerHell.makeMove: Rejected move at $index - isComputerTurn=$isComputerTurn, cell empty=${board[index].isEmpty}');
      return;
    }

    processMove(index, true);

    if (checkWinner().isNotEmpty || xMoveCount + oMoveCount == 30) {
      return;
    }

    isComputerTurn = true;
    onPlayerChanged?.call();
  }
  
  @override
  void resetGame() {
    super.resetGame();
    isComputerTurn = false;
    currentPlayer = player1Symbol;
    boardNotifier.value = List<String>.from(board);
  }
}