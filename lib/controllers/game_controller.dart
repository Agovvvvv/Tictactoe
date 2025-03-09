import 'dart:ui' show VoidCallback;
import 'package:vanishingtictactoe/models/utils/logger.dart';
import 'package:vanishingtictactoe/logic/game_logic_2players.dart';
import 'package:vanishingtictactoe/logic/game_logic_vscomputer.dart';
import 'package:vanishingtictactoe/logic/game_logic_online.dart';
import 'package:vanishingtictactoe/models/player.dart';
import 'package:vanishingtictactoe/services/history/local_match_history_service.dart';

class GameController {
  final GameLogic gameLogic;
  final Function(String) onGameEnd;
  final VoidCallback? onPlayerChanged;
  final LocalMatchHistoryService matchHistoryService = LocalMatchHistoryService();

  GameController({
    required this.gameLogic,
    required this.onGameEnd,
    this.onPlayerChanged,
  });

  void makeMove(int index) {
    gameLogic.makeMove(index);
    checkGameEnd();
  }

  void checkGameEnd([String? forcedWinner, bool isSurrendered = false]) {
    final winner = forcedWinner ?? gameLogic.checkWinner();
    final isDraw = winner == 'draw' || (winner.isEmpty && !gameLogic.board.contains(''));
    if (winner.isNotEmpty || isDraw) {
      onGameEnd(winner);
    }
  }

  void resetGame() {
    gameLogic.resetGame();
  }

  String getCurrentPlayerName(Player? player1, Player? player2) {
    logger.i('Current game state - Player1(${player1?.name}): ${gameLogic.player1Symbol}, '
        'Player2(${player2?.name}): ${gameLogic.player2Symbol}, Current: ${gameLogic.currentPlayer}');
    if (gameLogic is GameLogicVsComputer) {
      final vsComputer = gameLogic as GameLogicVsComputer;
      final isHumanTurn = !vsComputer.isComputerTurn;
      return isHumanTurn ? 'You' : 'Computer';
    }
    return gameLogic.currentPlayer == 'X'
        ? (player1?.name ?? 'Player 1')
        : (player2?.name ?? 'Player 2');
  }

  String getOnlinePlayerTurnText(GameLogicOnline onlineLogic, bool isConnecting) {
    if (isConnecting || !onlineLogic.isConnected) {
      return "Connecting...";
    }
    try {
      final opponentName = onlineLogic.opponentName.isNotEmpty
          ? onlineLogic.opponentName
          : 'Opponent';
      return onlineLogic.isLocalPlayerTurn
          ? "Your turn"
          : "$opponentName's turn";
    } catch (e) {
      logger.e('Error getting turn text: $e');
      return "Game in progress";
    }
  }

  bool isInteractionDisabled(bool isConnecting) {
    if (gameLogic is GameLogicVsComputer) {
      return (gameLogic as GameLogicVsComputer).isComputerTurn;
    } else if (gameLogic is GameLogicOnline) {
      return !(gameLogic as GameLogicOnline).isLocalPlayerTurn || isConnecting;
    }
    return false;
  }

  String? determineSurrenderWinner() {
    if (gameLogic is GameLogicVsComputer) {
      return (gameLogic as GameLogicVsComputer).computerPlayer.symbol;
    } else if (gameLogic is! GameLogicOnline) {
      return gameLogic.currentPlayer == 'X' ? 'O' : 'X';
    }
    return null;
  }
}