import 'game_logic_2players.dart';
import 'computer_player.dart';
import 'package:flutter/foundation.dart';
import '../models/utils/logger.dart';

class GameLogicVsComputer extends GameLogic {
  final ValueNotifier<List<String>> boardNotifier = ValueNotifier<List<String>>(List.filled(9, ''));
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
    boardNotifier.value = List<String>.from(board);
    logger.i('GameLogicVsComputer initialized: humanSymbol=$humanSymbol, currentPlayer=$currentPlayer');
  }

  void checkAndNotifyGameEnd() {
    final winner = checkWinner();
    logger.i('checkAndNotifyGameEnd: Checking for winner: $winner');
    
    if (winner.isNotEmpty) {
      logger.i('checkAndNotifyGameEnd: Winner detected: $winner');
      Future.delayed(const Duration(milliseconds: 100), () => onGameEnd(winner));
    } else if (xMoveCount + oMoveCount == 30) {
      logger.i('checkAndNotifyGameEnd: Draw detected');
      Future.delayed(const Duration(milliseconds: 100), () => onGameEnd('draw'));
    }
  }

  void processMove(int index, bool isHumanMove) {
    try {
      board[index] = currentPlayer;
      boardNotifier.value = List<String>.from(board);
      onPlayerChanged?.call();

      if (isHumanMove) {
        xMoves.add(index);
        xMoveCount++;
      } else {
        oMoves.add(index);
        oMoveCount++;
      }

      final winner = checkWinner();
      logger.i('processMove: Move at $index by ${isHumanMove ? "human" : "computer"}, winner check: $winner');
      
      if (winner.isNotEmpty) {
        logger.i('processMove: Winner detected: $winner');
        Future.delayed(const Duration(milliseconds: 100), () => onGameEnd(winner));
        return;
      }
      
      if (xMoveCount + oMoveCount == 30) {
        logger.i('processMove: Draw detected');
        Future.delayed(const Duration(milliseconds: 100), () => onGameEnd('draw'));
        return;
      }

      final moves = isHumanMove ? xMoves : oMoves;
      final moveCount = isHumanMove ? xMoveCount : oMoveCount;
      if (moveCount >= 4 && moves.length > 3) {
        final vanishIndex = moves.removeAt(0);
        board[vanishIndex] = '';
        boardNotifier.value = List<String>.from(board);
        onPlayerChanged?.call();
      }

      currentPlayer = isHumanMove ? player2Symbol : player1Symbol;
      isComputerTurn = isHumanMove;
      onPlayerChanged?.call();
    } catch (e) {
      logger.e('Error in processMove: $e');
      if (!isHumanMove) isComputerTurn = false;
    }
  }

  @override
  void makeMove(int index) {
    logger.i('GameLogicVsComputer.makeMove called for index $index, isComputerTurn=$isComputerTurn, currentPlayer=$currentPlayer');
    
    if (isComputerTurn || board[index].isNotEmpty) {
      logger.i('GameLogicVsComputer.makeMove: Rejected move at $index - isComputerTurn=$isComputerTurn, cell empty=${board[index].isEmpty}');
      return;
    }

    processMove(index, true);

    final winner = checkWinner();
    if (winner.isNotEmpty || xMoveCount + oMoveCount == 30) return;

    isComputerTurn = true;
    Future.delayed(const Duration(milliseconds: 200), () async {
      try {
        final move = await computerPlayer.getMove(List<String>.from(board));
        
        if (board[move].isEmpty) {
          board[move] = currentPlayer;
          boardNotifier.value = List<String>.from(board);
          onPlayerChanged?.call();

          oMoves.add(move);
          oMoveCount++;
          
          final winner = checkWinner();
          logger.i('Computer move made at $move, checking winner: $winner');
          
          if (winner.isNotEmpty) {
            logger.i('Computer wins with symbol $winner');
            Future.delayed(const Duration(milliseconds: 100), () => onGameEnd(winner));
            return;
          }
          
          if (oMoveCount >= 4 && oMoves.length > 3) {
            final vanishIndex = oMoves.removeAt(0);
            board[vanishIndex] = '';
            boardNotifier.value = List<String>.from(board);
            onPlayerChanged?.call();
          }
          
          if (xMoveCount + oMoveCount == 30) {
            Future.delayed(const Duration(milliseconds: 100), () => onGameEnd('draw'));
            return;
          }
          
          currentPlayer = player1Symbol;
          isComputerTurn = false;
          onPlayerChanged?.call();
        }
      } catch (e) {
        logger.e('Error in computer move: $e');
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