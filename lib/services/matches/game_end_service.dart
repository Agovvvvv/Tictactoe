import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vanishingtictactoe/logic/computer_player.dart';
import 'package:vanishingtictactoe/models/utils/logger.dart';
import 'package:vanishingtictactoe/logic/game_logic_2players.dart';
import 'package:vanishingtictactoe/logic/game_logic_vscomputer.dart';
import 'package:vanishingtictactoe/logic/game_logic_online.dart';
import 'package:vanishingtictactoe/models/player.dart';
import 'package:vanishingtictactoe/services/history/local_match_history_service.dart';
import 'package:vanishingtictactoe/services/history/match_history_updates.dart';
import 'package:vanishingtictactoe/providers/user_provider.dart';
import 'package:vanishingtictactoe/providers/mission_provider.dart';
import 'package:vanishingtictactoe/providers/hell_mode_provider.dart';
import 'package:vanishingtictactoe/screens/components/game_end_dialog.dart';

class GameEndService {
  final BuildContext context;
  final GameLogic gameLogic;
  final Player? player1;
  final Player? player2;
  final bool isOnlineGame;
  final LocalMatchHistoryService _matchHistoryService = LocalMatchHistoryService();
  bool isShowingDialog = false;

  GameEndService({
    required this.context,
    required this.gameLogic,
    required this.player1,
    required this.player2,
    this.isOnlineGame = false,
  });

  Future<void> handleGameEnd({
    String? forcedWinner,
    bool isSurrendered = false,
    required VoidCallback onPlayAgain,
  }) async {
    logger.i('_handleGameEnd called with forcedWinner: $forcedWinner, isSurrendered: $isSurrendered');

    if (isShowingDialog) {
      logger.i('Dialog already showing, ignoring game end call');
      return;
    }

    String winner = forcedWinner ?? '';
    if (winner.isEmpty) {
      winner = gameLogic.checkWinner();
      logger.i('Checked winner from game logic: $winner');
    }

    bool isDraw = winner == 'draw' || (winner.isEmpty && !gameLogic.board.contains(''));

    if (gameLogic is GameLogicVsComputer) {
      logger.i('Current board state: ${gameLogic.board}');
      if (winner.isEmpty) {
        winner = gameLogic.checkWinner();
        logger.i('Re-checked winner for computer game: $winner');
      }
      if (forcedWinner != null && forcedWinner.isNotEmpty) {
        logger.i('Using forced winner from computer logic: $forcedWinner');
        winner = forcedWinner;
        isDraw = false;
      }
    }

    if (gameLogic is GameLogicOnline) {
      final onlineLogic = gameLogic as GameLogicOnline;
      final match = onlineLogic.currentMatch;
      if (match != null && match.status == 'completed') {
        if (match.winner.isNotEmpty && match.winner != 'draw') {
          winner = match.winner;
          isDraw = false;
          logger.i('Using match winner from completed game: $winner');
        } else if (match.winner == 'draw' || !match.board.contains('')) {
          isDraw = true;
          logger.i('Game is a draw according to match status');
        }
      }
    }

    logger.i('Final game end state: winner=$winner, isDraw=$isDraw');

    if (winner.isNotEmpty || isDraw) {
      logger.i('Game end detected, preparing to show dialog');
      String winnerName;
      bool isHumanWinner = false;

      if (gameLogic is GameLogicVsComputer) {
        final vsComputer = gameLogic as GameLogicVsComputer;
        isHumanWinner = winner == vsComputer.player1Symbol;
        final player1Name = player1?.name ?? 'Player 1';
        winnerName = isHumanWinner ? player1Name : 'Computer';
      } else if (gameLogic is GameLogicOnline) {
        final online = gameLogic as GameLogicOnline;
        if (isDraw || winner == 'draw') {
          winnerName = 'Nobody';
        } else {
          final match = online.currentMatch;
          if (match != null && match.winner.isNotEmpty) {
            if (match.winner == match.player1.id) {
              winnerName = match.player1.name;
            } else {
              winnerName = match.player2.name;
            }
          } else {
            winnerName = 'Unknown';
          }
        }
      } else {
        final player1Name = player1?.name ?? 'Player 1';
        final player2Name = player2?.name ?? 'Player 2';
        winnerName = winner == 'X' ? player1Name : player2Name;

        if (!isDraw && (gameLogic is! GameLogicVsComputer)) {
          final player1WentFirst = gameLogic.player1Symbol == 'X';
          logger.i('Saving match history for 2-player game - Type check: ${gameLogic.runtimeType}');
          await _matchHistoryService.saveMatch(
            player1: player1Name,
            player2: player2Name,
            winner: winnerName,
            player1WentFirst: player1WentFirst,
            player1Symbol: player1?.symbol ?? 'X',
            player2Symbol: player2?.symbol ?? 'O',
          );
          MatchHistoryUpdates.notifyUpdate();
        } else {
          logger.i('Skipping match history save for 2-player section - isDraw: $isDraw, '
              'isComputer: ${gameLogic is GameLogicVsComputer}');
        }
      }

      String message;
      if (isSurrendered) {
        message = winnerName == 'Computer' ? 'You surrendered!' : '$winnerName wins by surrender!';
      } else if (isDraw) {
        message = 'It\'s a draw!';
      } else if (gameLogic is GameLogicOnline) {
        final online = gameLogic as GameLogicOnline;
        final match = online.currentMatch;
        if (match != null) {
          final localPlayerId = online.localPlayerId;
          final isLocalPlayerWinner = match.winner == localPlayerId;
          message = isLocalPlayerWinner ? 'You win!' : '$winnerName wins!';
        } else {
          message = '$winnerName wins!';
        }
      } else {
        message = isHumanWinner ? 'You win!' : 'Computer wins!';
      }

      int? winnerMoves;
      if (!isDraw) {
        winnerMoves = winner == 'X' ? gameLogic.xMoveCount : gameLogic.oMoveCount;
      }

      logger.i('Game type check: ${gameLogic.runtimeType}');
      if (gameLogic is GameLogicVsComputer) {
        logger.i('Handling computer game end - winner: $winner, isDraw: $isDraw');
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final missionProvider = Provider.of<MissionProvider>(context, listen: false);
        final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);

        final isHellMode = hellModeProvider.isHellModeActive;

        GameDifficulty? difficulty;
        if (player2 is ComputerPlayer) {
          final computerPlayer = player2 as ComputerPlayer;
          difficulty = computerPlayer.difficulty;
        }

        if (userProvider.user != null) {
          userProvider.updateGameStats(
            isWin: isDraw ? false : isHumanWinner,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isHumanWinner ? winnerMoves : null),
            isOnline: false,
            isFriendlyMatch: isSurrendered,
          );

          if (!isSurrendered) {
            missionProvider.trackGamePlayed(
              isHellMode: isHellMode,
              isWin: isHumanWinner,
              difficulty: difficulty,
            );
          }

          logger.i('Game stats updated - Winner: ${isDraw ? 'Draw' : (isHumanWinner ? 'Human' : 'Computer')}, '
              'Winner Moves: $winnerMoves, Hell Mode: $isHellMode');
        }
      } else if (gameLogic is GameLogicOnline) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final missionProvider = Provider.of<MissionProvider>(context, listen: false);
        final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);

        final isHellMode = hellModeProvider.isHellModeActive;

        if (userProvider.user != null) {
          final online = gameLogic as GameLogicOnline;
          final isWin = online.localPlayerId == online.currentMatch?.winner;

          userProvider.updateGameStats(
            isWin: isDraw ? false : isWin,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isWin ? winnerMoves : null),
            isOnline: true,
            isFriendlyMatch: isSurrendered,
          );

          if (!isSurrendered) {
            missionProvider.trackGamePlayed(
              isHellMode: isHellMode,
              isWin: isWin,
              difficulty: null,
            );
          }

          logger.i('Game stats updated - Winner: ${isDraw ? 'Draw' : (isWin ? 'Local Player' : 'Opponent')}, '
              'Winner Moves: $winnerMoves, Hell Mode: $isHellMode');
        }
      } else if (gameLogic is! GameLogicVsComputer) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final missionProvider = Provider.of<MissionProvider>(context, listen: false);
        final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);

        final isHellMode = hellModeProvider.isHellModeActive;

        if (userProvider.user != null) {
          final isWin = winner == userProvider.user!.username;

          userProvider.updateGameStats(
            isWin: isDraw ? false : isWin,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isWin ? winnerMoves : null),
            isOnline: false,
            isFriendlyMatch: true,
          );

          if (!isSurrendered) {
            missionProvider.trackGamePlayed(
              isHellMode: isHellMode,
              isWin: isWin,
              difficulty: null,
            );
          }

          logger.i('Game stats updated for 2-player game - No XP awarded, Hell Mode: $isHellMode');
        }
      }

      logger.i('Scheduling dialog to be shown');

      logger.i('Will show dialog in 100ms');
      Future.delayed(Duration(milliseconds: 100), () {
        if (context.mounted && !isShowingDialog) {
          logger.i('Now showing dialog');
          isShowingDialog = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => GameEndDialog(
              isSurrendered: isSurrendered,
              message: message,
              isOnlineGame: isOnlineGame,
              isVsComputer: gameLogic is GameLogicVsComputer,
              player1: player1,
              player2: player2,
              winnerMoves: winnerMoves,
              onPlayAgain: onPlayAgain,
            ),
          ).then((_) {
            isShowingDialog = false;
          });
        }
      });
    }
  }
}