import 'package:flutter/material.dart';
import '../../../logic/game_logic_2players.dart';
import '../../../logic/game_logic_vscomputer_hell.dart';
import '../../../models/player.dart';
import '../../../logic/computer_player.dart';
import '../../components/grid_cell.dart';

import 'package:provider/provider.dart';

import '../../../providers/user_provider.dart';
import '../../../providers/mission_provider.dart';
import '../../../models/utils/logger.dart';
import '../../components/game_end_dialog.dart';

abstract class BaseHellGameState<T extends StatefulWidget> extends State<T> {
  late GameLogic gameLogic;
  bool isShowingDialog = false;

  // Abstract methods that must be implemented by child classes
  void handleGameEnd([String? forcedWinner]);
  void updateState();
  void onComputerMoveComplete(int move);

  // Protected methods for computer move handling
  void makeComputerMove() {
    if (gameLogic is! GameLogicVsComputerHell || !mounted) return;

    final vsComputer = gameLogic as GameLogicVsComputerHell;
    if (!vsComputer.isComputerTurn) return;

    Future.delayed(Duration(milliseconds: 200), () {
      if (!mounted) return;

      final computerPlayer = vsComputer.computerPlayer;
      final emptyCells = List.generate(9, (index) => index)
          .where((index) => vsComputer.board[index].isEmpty)
          .toList();

      if (emptyCells.isEmpty) return;

      computerPlayer.getMove(List<String>.from(vsComputer.board)).then((move) {
        if (mounted && vsComputer.board[move].isEmpty) {
          onComputerMoveComplete(move);
        } else {
          final randomMove = emptyCells[DateTime.now().millisecondsSinceEpoch % emptyCells.length];
          onComputerMoveComplete(randomMove);
        }
      }).catchError((e) {
        final randomMove = emptyCells[DateTime.now().millisecondsSinceEpoch % emptyCells.length];
        onComputerMoveComplete(randomMove);
      });
    });
  }

  // Protected method to check game end
  void checkGameEnd() {
    final winner = gameLogic.checkWinner();
    if (winner.isNotEmpty || gameLogic.board.every((cell) => cell.isNotEmpty)) {
      handleGameEnd(winner);
    }
  }

  // Protected method to get winner name
  String getWinnerName(String winner, bool isDraw, Player? player1, Player? player2) {
    if (isDraw) return 'Nobody';
    
    return gameLogic is GameLogicVsComputerHell
        ? winner == (gameLogic as GameLogicVsComputerHell).player1Symbol
            ? player1?.name ?? 'Player 1'
            : 'Computer'
        : winner == 'X'
            ? player1?.name ?? 'Player 1'
            : player2?.name ?? 'Player 2';
  }

  // Protected method to check if human is winner
  bool isHumanWinner(String winner, Player? player1) {
    return gameLogic is GameLogicVsComputerHell
        ? winner == (gameLogic as GameLogicVsComputerHell).player1Symbol
        : winner == player1?.symbol;
  }

  // Common grid building logic
  Widget buildGameGrid(List<String> board, bool isComputerTurn, void Function(int) onCellTap) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: List.generate(9, (index) {
        return AbsorbPointer(
          absorbing: isComputerTurn,
          child: GridCell(
            key: ValueKey('cell_${index}_${board[index]}'),
            value: board[index],
            index: index,
            isVanishing: gameLogic.getNextToVanish() == index,
            onTap: () => onCellTap(index),
          ),
        );
      }),
    );
  }

  // Main game end handling with stats tracking and full dialog options
  void showMainGameEndDialog({
    required String winner,
    required bool isDraw,
    required Player? player1,
    required Player? player2,
    required BuildContext context,
    required bool isOnlineGame,
    required VoidCallback onPlayAgain,
    required VoidCallback onBackToMenu,
  }) {
    if (!mounted || isShowingDialog) return;

    final isHumanWinner = this.isHumanWinner(winner, player1);
    final winnerName = getWinnerName(winner, isDraw, player1, player2);
    final message = isDraw ? 'It\'s a draw!' : '$winnerName wins!';

    // Update stats and missions for main game only
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final missionProvider = Provider.of<MissionProvider>(context, listen: false);

    if (userProvider.user != null) {
      GameDifficulty? difficulty;
      if (player2 is ComputerPlayer) {
        difficulty = player2.difficulty;
      }

      final isHellMode = true;
      int? winnerMoves;
      if (!isDraw) {
        winnerMoves = winner == 'X' ? gameLogic.xMoveCount : gameLogic.oMoveCount;
      }

      userProvider.updateGameStats(
        isWin: isDraw ? false : isHumanWinner,
        isDraw: isDraw,
        movesToWin: isDraw ? null : (isHumanWinner ? winnerMoves : null),
        isOnline: isOnlineGame,
        isFriendlyMatch: gameLogic is! GameLogicVsComputerHell,
      );

      missionProvider.trackGamePlayed(
        isHellMode: isHellMode,
        isWin: isHumanWinner,
        difficulty: difficulty,
      );

      logger.i('Hell Mode game stats updated - Winner: ${isDraw ? 'Draw' : (isHumanWinner ? 'Human' : 'Computer')}, Winner Moves: $winnerMoves');
    }

    _showEndDialog(
      context: context,
      message: message,
      isOnlineGame: isOnlineGame,
      player1: player1,
      player2: player2,
      onPlayAgain: onPlayAgain,
      onBackToMenu: onBackToMenu,
      backButtonText: 'Back to Menu',
      showPlayAgain: true,
    );
  }

  // Cell game end handling with simplified dialog
  void showCellGameEndDialog({
    required String winner,
    required bool isDraw,
    required Player? player1,
    required Player? player2,
    required BuildContext context,
    required VoidCallback onBackToMainBoard,
  }) {
    if (!mounted || isShowingDialog) return;

    final winnerName = getWinnerName(winner, isDraw, player1, player2);
    final message = isDraw ? 'It\'s a draw!' : '$winnerName wins!';

    Future.delayed(Duration(milliseconds: 100), () {
      if (!mounted || isShowingDialog) return;

      isShowingDialog = true;
      showDialog(
        context: context.mounted ? context : context,
        barrierDismissible: false,
        builder: (context) => GameEndDialog(
          message: message,
          isOnlineGame: false,
          isVsComputer: gameLogic is GameLogicVsComputerHell,
          player1: player1,
          player2: player2,
          onPlayAgain: () {},
          onBackToMenu: () {
            isShowingDialog = false;
            onBackToMainBoard();
          },
          isCellGame: true,
        ),
      ).then((_) => isShowingDialog = false);
    });
  }

  // Private helper method for showing the dialog
  void _showEndDialog({
    required BuildContext context,
    required String message,
    required bool isOnlineGame,
    required Player? player1,
    required Player? player2,
    VoidCallback? onPlayAgain,
    required VoidCallback onBackToMenu,
    required String backButtonText,
    required bool showPlayAgain,
  }) {
    Future.delayed(Duration(milliseconds: 100), () {
      if (!mounted || isShowingDialog) return;

      isShowingDialog = true;
      showDialog(
        context: context.mounted ? context : context,
        barrierDismissible: false,
        builder: (context) => GameEndDialog(
          message: message,
          isOnlineGame: isOnlineGame,
          isVsComputer: gameLogic is GameLogicVsComputerHell,
          player1: player1,
          player2: player2,
          onPlayAgain: showPlayAgain && onPlayAgain != null ? () {
            isShowingDialog = false;
            onPlayAgain();
          } : () {},
          onBackToMenu: () {
            isShowingDialog = false;
            onBackToMenu();
          },
          //backButtonText: backButtonText,
        ),
      ).then((_) => isShowingDialog = false);
    });
  }

  String getCurrentPlayerName(Player? player1, Player? player2) {
    if (gameLogic is GameLogicVsComputerHell) {
      final vsComputer = gameLogic as GameLogicVsComputerHell;
      return vsComputer.isComputerTurn ? 'Computer' : 'You';
    }
    return gameLogic.currentPlayer == 'X' 
        ? player1?.name ?? 'Player 1' 
        : player2?.name ?? 'Player 2';
  }

  // Common initialization logic
  GameLogic initializeGameLogic({
    required Player? player1,
    required Player? player2,
    required Function(String?) onGameEnd,
    required Function() onPlayerChanged,
    GameLogic? existingLogic,
    bool? player1GoesFirst,
  }) {
    final computerPlayer = player2 is ComputerPlayer ? player2  : null;

    return existingLogic ?? (computerPlayer != null
        ? GameLogicVsComputerHell(
            onGameEnd: onGameEnd,
            onPlayerChanged: onPlayerChanged,
            computerPlayer: computerPlayer,
            humanSymbol: player1?.symbol ?? 'X',
          )
        : GameLogic(
            onGameEnd: onGameEnd,
            onPlayerChanged: onPlayerChanged,
            player1Symbol: player1?.symbol ?? 'X',
            player2Symbol: player2?.symbol ?? 'O',
            player1GoesFirst: player1GoesFirst ?? player1?.symbol == 'X',
          ));
  }

  

  // Common grid building logic
  Widget buildHellGrid({
    required List<String> board,
    required bool isComputerTurn,
    required Function(int) onCellTap,
  }) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: List.generate(9, (index) {
        return AbsorbPointer(
          absorbing: isComputerTurn,
          child: GridCell(
            key: ValueKey('cell_${index}_${board[index]}'),
            value: board[index],
            index: index,
            isVanishing: gameLogic.getNextToVanish() == index,
            onTap: () => onCellTap(index),
          ),
        );
      }),
    );
  }

}
