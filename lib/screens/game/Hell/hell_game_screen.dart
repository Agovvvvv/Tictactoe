import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../logic/game_logic_2players.dart';
import '../../../../logic/game_logic_vscomputer_hell.dart';
import '../../../../models/player.dart';
import '../../../../logic/computer_player.dart';

import 'cell_game_screen.dart';
import 'base_hell_game_state.dart';

class HellGameScreen extends StatefulWidget {
  final Player? player1;
  final Player? player2;
  final GameLogic? logic;

  const HellGameScreen({
    super.key,
    this.player1,
    this.player2,
    this.logic, 
  });

  @override
  State<HellGameScreen> createState() => _HellGameScreenState();
}

class _HellGameScreenState extends BaseHellGameState<HellGameScreen> {

  @override
  void initState() {
    super.initState();
    gameLogic = initializeGameLogic(
      player1: widget.player1,
      player2: widget.player2,
      onGameEnd: handleGameEnd,
      onPlayerChanged: updateState,
      existingLogic: widget.logic,
    );

    final computerPlayer = widget.player2 is ComputerPlayer ? widget.player2 as ComputerPlayer : null;
    if (computerPlayer != null && gameLogic is GameLogicVsComputerHell) {
      final vsComputer = gameLogic as GameLogicVsComputerHell;
      final isComputerTurn = vsComputer.currentPlayer != (widget.player1?.symbol ?? 'X');

      if (isComputerTurn) {
        vsComputer.isComputerTurn = true;
        Future.delayed(Duration(milliseconds: 200), makeComputerMove);
      }
    }
  }

  @override
  void updateState() {
    if (mounted) setState(() {});
  }

  @override
  void onComputerMoveComplete(int move) {
    _navigateToVanishingGame(move);
  }

  @override
  void handleGameEnd([String? forcedWinner]) {
    final winner = forcedWinner ?? gameLogic.checkWinner();
    final isDraw = winner.isEmpty && gameLogic.board.every((cell) => cell.isNotEmpty);

    if (winner.isNotEmpty || isDraw) {
      showMainGameEndDialog(
        winner: winner,
        isDraw: isDraw,
        player1: widget.player1,
        player2: widget.player2,
        context: context,
        isOnlineGame: false,
        onPlayAgain: () {
          setState(() {
            gameLogic.resetGame();
          });
        },
        onBackToMenu: () {
          Navigator.of(context).pop({
            'player1': widget.player1?.name,
            'player2': widget.player2?.name,
            'winner': winner,
            'player1WentFirst': gameLogic.xMoveCount >= gameLogic.oMoveCount,
            'player1Symbol': widget.player1?.symbol ?? 'X',
            'player2Symbol': widget.player2?.symbol ?? 'O',
          });
        },
      );
    }
  }

  void _navigateToVanishingGame(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CellGameScreen(
          player1: widget.player1,
          player2: widget.player2,
          initialCell: index,
          currentPlayer: gameLogic.currentPlayer,
          mainBoard: gameLogic.board,
          onGameComplete: (winnerSymbol) {
            if (winnerSymbol.isNotEmpty && winnerSymbol != 'draw') {
              setState(() {
                gameLogic.board[index] = winnerSymbol;
                gameLogic.currentPlayer = winnerSymbol == 'X' ? 'O' : 'X';
                if (gameLogic is GameLogicVsComputerHell) {
                  final vsComputer = gameLogic as GameLogicVsComputerHell;
                  vsComputer.boardNotifier.value = List<String>.from(gameLogic.board);
                  vsComputer.isComputerTurn = winnerSymbol == (widget.player1?.symbol ?? 'X');
                }
              });
              // Check if the game has ended
              final winner = gameLogic.checkWinner();
              final isDraw = winner.isEmpty && gameLogic.board.every((cell) => cell.isNotEmpty);
              
              if (winner.isNotEmpty || isDraw) {
                handleGameEnd(winner);
              } else if (gameLogic is GameLogicVsComputerHell && (gameLogic as GameLogicVsComputerHell).isComputerTurn) {
                Future.delayed(Duration(milliseconds: 200), makeComputerMove);
              }
            } else {
              checkGameEnd();
            }
          },
        ),
      ),
    );
  }

  Widget _buildGrid(List<String> board, bool isComputerTurn) {
    return buildGameGrid(board, isComputerTurn, _navigateToVanishingGame);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.red, Colors.black],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.red,
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.yellow, Colors.red, Colors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      "HELL MODE",
                      style: GoogleFonts.pressStart2p(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    getCurrentPlayerName(widget.player1, widget.player2) == 'You' ? 'Your turn' : "It's ${getCurrentPlayerName(widget.player1, widget.player2)}'s turn",
                    style: GoogleFonts.pressStart2p(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: gameLogic is GameLogicVsComputerHell
                        ? ValueListenableBuilder<List<String>>(
                            valueListenable: (gameLogic as GameLogicVsComputerHell).boardNotifier,
                            builder: (context, board, child) => _buildGrid(board, (gameLogic as GameLogicVsComputerHell).isComputerTurn),
                        )
                        : _buildGrid(gameLogic.board, false),
                  ),
                ],
              ),
            ),
          ),
         
        ],
      ),
    );
  }
}