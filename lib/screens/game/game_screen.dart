import 'package:flutter/material.dart';
import 'package:vanishingtictactoe/models/utils/win_checker.dart';
import 'package:vanishingtictactoe/logic/game_logic_2players.dart';
import 'package:vanishingtictactoe/logic/game_logic_vscomputer.dart';
import 'package:vanishingtictactoe/logic/game_logic_online.dart';
import 'package:vanishingtictactoe/models/player.dart';
import 'package:vanishingtictactoe/logic/computer_player.dart';
import 'package:vanishingtictactoe/models/utils/logger.dart';
import 'package:vanishingtictactoe/controllers/game_controller.dart';
import 'package:vanishingtictactoe/services/matches/game_end_service.dart';
import 'package:vanishingtictactoe/widgets/game_board.dart';
import 'package:vanishingtictactoe/widgets/turn_indicator.dart';
import 'package:vanishingtictactoe/widgets/surrender_button.dart';

class GameScreen extends StatefulWidget {
  final Player? player1;
  final Player? player2;
  final GameLogic? logic;
  final bool isOnlineGame;

  const GameScreen({
    super.key,
    this.player1,
    this.player2,
    this.logic,
    this.isOnlineGame = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  late GameEndService _gameEndService;
  bool _isConnecting = false;
  WinChecker winChecker = WinChecker();

  @override
  void initState() {
    super.initState();
    _gameController = GameController(
      gameLogic: widget.logic ?? _createDefaultGameLogic(),
      onGameEnd: (winner) => _gameEndService.handleGameEnd(
        forcedWinner: winner,
        onPlayAgain: _handlePlayAgain,
      ),
      onPlayerChanged: () {
        if (mounted) {
          setState(() {}); // Ensure UI rebuilds when player changes
        }
      },
    );
    _gameEndService = GameEndService(
      context: context,
      gameLogic: _gameController.gameLogic,
      player1: widget.player1,
      player2: widget.player2,
      isOnlineGame: widget.isOnlineGame,
    );

    _setupGameListeners();
  }

  GameLogic _createDefaultGameLogic() {
    final computerPlayer = widget.player2 is ComputerPlayer
        ? widget.player2 as ComputerPlayer
        : null;

    return computerPlayer != null
        ? GameLogicVsComputer(
            onGameEnd: (winner) => _gameEndService.handleGameEnd(
              forcedWinner: winner,
              onPlayAgain: _handlePlayAgain,
            ),
            onPlayerChanged: () {
              if (mounted) {
                setState(() {}); // Ensure UI rebuilds when player changes
              }
            },
            computerPlayer: computerPlayer,
            humanSymbol: widget.player1?.symbol ?? 'X',
          )
        : GameLogic(
            onGameEnd: (winner) => _gameEndService.handleGameEnd(
              forcedWinner: winner,
              onPlayAgain: _handlePlayAgain,
            ),
            onPlayerChanged: () {
              if (mounted) {
                setState(() {}); // Ensure UI rebuilds when player changes
              }
            },
            player1Symbol: widget.player1?.symbol ?? 'X',
            player2Symbol: widget.player2?.symbol ?? 'O',
            player1GoesFirst: (widget.player1?.symbol == 'X'),
          );
  }

  void _setupGameListeners() {
    if (_gameController.gameLogic is GameLogicVsComputer) {
      final computerLogic = _gameController.gameLogic as GameLogicVsComputer;
      computerLogic.boardNotifier.addListener(() {
        if (!_gameEndService.isShowingDialog) {
          final winner = computerLogic.checkWinner();
          if (winner.isNotEmpty) {
            logger.i('Detected computer win from board listener: $winner');
            _gameEndService.handleGameEnd(
              forcedWinner: winner,
              onPlayAgain: _handlePlayAgain,
            );
          }
        }
      });
    }

    if (_gameController.gameLogic is GameLogicOnline) {
      final onlineLogic = _gameController.gameLogic as GameLogicOnline;
      try {
        Future.delayed(Duration.zero, () {
          onlineLogic.boardNotifier.addListener(() {
            if (onlineLogic.currentMatch?.status == 'completed') {
              final winner = onlineLogic.currentMatch?.winner ?? '';
              if (winner.isNotEmpty) {
                logger.i('Detected game completion from board update. Winner: $winner');
                _gameEndService.handleGameEnd(
                  forcedWinner: winner,
                  onPlayAgain: _handlePlayAgain,
                );
              }
            }
          });
        });
      } catch (e) {
        logger.e('Error setting up game end listener: $e');
      }

      onlineLogic.onError = (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      };

      onlineLogic.onConnectionStatusChanged = (isConnected) {
        if (!mounted) return;
        setState(() {
          _isConnecting = !isConnected;
        });
      };
    }
  }

  void _handlePlayAgain() {
    if (widget.isOnlineGame) {
      if (_gameController.gameLogic is GameLogicOnline) {
        (_gameController.gameLogic as GameLogicOnline).dispose();
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _gameController.resetGame();
      });
    }
  }

  @override
  void dispose() {
    if (_gameController.gameLogic is GameLogicOnline) {
      (_gameController.gameLogic as GameLogicOnline).dispose();
    }
    _gameController.gameLogic.dispose(); // Dispose of the ValueNotifier
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (_gameController.gameLogic is GameLogicOnline) {
          (_gameController.gameLogic as GameLogicOnline).dispose();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFF0F0F0)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        TurnIndicatorWidget(
                          gameLogic: _gameController.gameLogic,
                          player1: widget.player1,
                          player2: widget.player2,
                          isConnecting: _isConnecting,
                          getCurrentPlayerName: _gameController.getCurrentPlayerName,
                          getOnlinePlayerTurnText: _gameController.getOnlinePlayerTurnText,
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GameBoardWidget(
                            isInteractionDisabled: _gameController.isInteractionDisabled(_isConnecting),
                            onCellTapped: _gameController.makeMove,
                            gameLogic: _gameController.gameLogic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SurrenderButtonWidget(
              onSurrender: () => _gameEndService.handleGameEnd(
                forcedWinner: _gameController.determineSurrenderWinner(),
                isSurrendered: true,
                onPlayAgain: _handlePlayAgain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}