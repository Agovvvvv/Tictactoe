import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../logic/game_logic_vscomputer_hell.dart';
import '../../../models/player.dart';
import '../../../logic/computer_player.dart';
import '../../../widgets/mini_board_display.dart';
import 'base_hell_game_state.dart';

class CellGameScreen extends StatefulWidget {
  final Player? player1;
  final Player? player2;
  final int initialCell;
  final Function(String) onGameComplete;
  final String currentPlayer;
  final List<String> mainBoard;

  const CellGameScreen({
    super.key,
    this.player1,
    this.player2,
    required this.initialCell,
    required this.onGameComplete,
    required this.currentPlayer,
    required this.mainBoard,
  });

  @override
  State<CellGameScreen> createState() => _CellGameScreenState();
}

class _CellGameScreenState extends BaseHellGameState<CellGameScreen> {

  @override
  void initState() {
    super.initState();
    final computerPlayer = widget.player2 is ComputerPlayer ? widget.player2 as ComputerPlayer : null;
    final isComputerFirst = computerPlayer != null && widget.currentPlayer == (widget.player2?.symbol ?? 'O');

    gameLogic = initializeGameLogic(
      player1: widget.player1,
      player2: widget.player2,
      onGameEnd: handleGameEnd,
      onPlayerChanged: updateState,
      player1GoesFirst: widget.currentPlayer == 'X',
    );

  if (computerPlayer != null) {
    gameLogic.currentPlayer = isComputerFirst ? widget.player2?.symbol ?? 'O' : widget.player1?.symbol ?? 'X';
    (gameLogic as GameLogicVsComputerHell).isComputerTurn = isComputerFirst;

    if (isComputerFirst && mounted) {
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
    if (!mounted || (gameLogic is! GameLogicVsComputerHell)) return;
    
    final vsComputer = gameLogic as GameLogicVsComputerHell;
    vsComputer.isComputerTurn = false;
    
    setState(() {
      vsComputer.board[move] = vsComputer.player2Symbol;
      vsComputer.boardNotifier.value = List<String>.from(vsComputer.board);
      vsComputer.oMoves.add(move);
      vsComputer.oMoveCount++;

      handleGameEnd();

      if (vsComputer.oMoveCount >= 4 && vsComputer.oMoves.length > 3) {
        final vanishIndex = vsComputer.oMoves.removeAt(0);
        vsComputer.board[vanishIndex] = '';
        vsComputer.boardNotifier.value = List<String>.from(vsComputer.board);
      }

      vsComputer.currentPlayer = vsComputer.player1Symbol;
    });
    
  }

  @override
  void handleGameEnd([String? forcedWinner]) {
    final winner = forcedWinner ?? gameLogic.checkWinner();
    final isDraw = winner.isEmpty && gameLogic.board.every((cell) => cell.isNotEmpty);

    if (winner.isNotEmpty || isDraw) {
      showCellGameEndDialog(
        winner: winner,
        isDraw: isDraw,
        player1: widget.player1,
        player2: widget.player2,
        context: context,
        onBackToMainBoard: () {
          widget.onGameComplete(winner);
          Navigator.of(context).pop();
        },
      );
    }
  }

  Widget _buildGrid(List<String> board, bool isComputerTurn) {
    return buildGameGrid(
      board,
      isComputerTurn,
      (index) {
        if (gameLogic is GameLogicVsComputerHell && (gameLogic as GameLogicVsComputerHell).isComputerTurn) return;

        setState(() {
          gameLogic.makeMove(index);
        });

        final winner = gameLogic.checkWinner();
        final isDraw = winner.isEmpty && gameLogic.board.every((cell) => cell.isNotEmpty);
        
        if (winner.isNotEmpty || isDraw) {
          handleGameEnd(winner);
        } else if (gameLogic is GameLogicVsComputerHell && (gameLogic as GameLogicVsComputerHell).isComputerTurn) {
          Future.delayed(Duration(milliseconds: 200), makeComputerMove);
        }
      },
    );
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
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      Text(
                        "MAIN BOARD",
                        style: GoogleFonts.pressStart2p(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MiniBoardDisplay(
                        board: widget.mainBoard,
                        highlightedCell: widget.initialCell,
                      ),
                    ],
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