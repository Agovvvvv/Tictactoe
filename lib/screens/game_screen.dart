import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../logic/game_logic_2players.dart';
import '../logic/game_logic_vscomputer.dart';
import '../logic/game_logic_online.dart';
import '../models/player.dart';
import '../logic/computer_player.dart';
import 'components/grid_cell.dart';
import 'components/footer.dart';
import 'components/game_end_dialog.dart';
import 'package:provider/provider.dart';
import '../services/local_match_history_service.dart';
import '../services/match_history_updates.dart';
import '../providers/user_provider.dart';

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
  late GameLogic gameLogic;
  bool _isConnecting = false;
  final LocalMatchHistoryService _matchHistoryService = LocalMatchHistoryService();

  @override
  void initState() {
    super.initState();
    final computerPlayer = widget.player2 is ComputerPlayer 
        ? widget.player2 as ComputerPlayer 
        : null;

    gameLogic = widget.logic ?? (computerPlayer != null
        ? GameLogicVsComputer(
            onGameEnd: (winner) => _handleGameEnd(),
            onPlayerChanged: () {
              if (mounted) {
                setState(() {
                }); 
              }
            },
            computerPlayer: computerPlayer,
            humanSymbol: widget.player1?.symbol ?? 'X',
          )
        : GameLogic(
            onGameEnd: (winner) => _handleGameEnd(),
            onPlayerChanged: () {
              if (mounted) {
                setState(() {
                }); 
              }
            },
            player1Symbol: widget.player1?.symbol ?? 'X',
            player2Symbol: widget.player2?.symbol ?? 'O',
            player1GoesFirst: (widget.player1?.symbol == 'X'),  // X always goes first
          ));

    // Set up error handling and connection status for online games
    if (gameLogic is GameLogicOnline) {
      final onlineLogic = gameLogic as GameLogicOnline;
      onlineLogic.onError = (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message))
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

  String _getCurrentPlayerName() {
    print('Current game state - Player1(${widget.player1?.name}): ${gameLogic.player1Symbol}, Player2(${widget.player2?.name}): ${gameLogic.player2Symbol}, Current: ${gameLogic.currentPlayer}');
    if (gameLogic is GameLogicVsComputer) {
      final vsComputer = gameLogic as GameLogicVsComputer;
      final isHumanTurn = !vsComputer.isComputerTurn;
      return isHumanTurn ? 'You' : 'Computer';
    }
    return gameLogic.currentPlayer == 'X'
        ? (widget.player1?.name ?? 'Player 1')
        : (widget.player2?.name ?? 'Player 2');
  }

  String _getOnlinePlayerTurnText(GameLogicOnline onlineLogic) {
    if (_isConnecting || !onlineLogic.isConnected) {
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
      print('Error getting turn text: $e');
      return "Game in progress";
    }
  }

  bool _isShowingDialog = false;

  Future<void> _handleGameEnd() async {
    if (_isShowingDialog) return;
    
    final winner = gameLogic.checkWinner();
    final isDraw = winner.isEmpty && !gameLogic.board.contains('');
    
    if (winner.isNotEmpty || isDraw) {
      _isShowingDialog = true;
      String winnerName;
      bool isHumanWinner = false;
      
      if (gameLogic is GameLogicVsComputer) {
        final vsComputer = gameLogic as GameLogicVsComputer;
        isHumanWinner = winner == vsComputer.player1Symbol;
        final player1Name = widget.player1?.name ?? 'Player 1';
        winnerName = isHumanWinner ? player1Name : 'Computer';
      } else if (gameLogic is GameLogicOnline) {
        final online = gameLogic as GameLogicOnline;
        final player1Name = widget.player1?.name ?? 'Player 1';
        winnerName = online.localPlayerSymbol == winner ? player1Name : online.opponentName;
      } else {
        // Local two-player game
        final player1Name = widget.player1?.name ?? 'Player 1';
        final player2Name = widget.player2?.name ?? 'Player 2';
        winnerName = winner == 'X' ? player1Name : player2Name;
        
        // Save match result to local history
        if (!isDraw) {
          final player1WentFirst = gameLogic.player1Symbol == 'X';
          
          await _matchHistoryService.saveMatch(
            player1: player1Name,
            player2: player2Name,
            winner: winnerName,
            player1WentFirst: player1WentFirst,
            player1Symbol: widget.player1?.symbol ?? 'X',
            player2Symbol: widget.player2?.symbol ?? 'O',
          );
          
          // Notify history screen to update
          MatchHistoryUpdates.notifyUpdate();
        }
      }
      String message = isDraw ? 'It\'s a draw!' : '$winnerName wins!';
      
      // Get winner's moves count
      int? winnerMoves;
      if (!isDraw) {
        winnerMoves = winner == 'X' ? gameLogic.xMoveCount : gameLogic.oMoveCount;
      }
      
      // Update game stats if it's a computer game
      if (gameLogic is GameLogicVsComputer) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.user != null) {
          userProvider.updateGameStats(
            isWin: isDraw ? false : isHumanWinner,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isHumanWinner ? winnerMoves : null), // Only count human wins
            isOnline: false,
          );
          print('Game stats updated - Winner: ${isDraw ? 'Draw' : (isHumanWinner ? 'Human' : 'Computer')}, Winner Moves: $winnerMoves');
        }
      } else if (gameLogic is GameLogicOnline) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.user != null) {
          final online = gameLogic as GameLogicOnline;
          final isWin = online.localPlayerSymbol == winner;
          userProvider.updateGameStats(
            isWin: isDraw ? false : isWin,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isWin ? winnerMoves : null), // Only count local player wins
            isOnline: true,
          );
          print('Game stats updated - Winner: ${isDraw ? 'Draw' : (isWin ? 'Local Player' : 'Opponent')}, Winner Moves: $winnerMoves');
        }
      }
      
      // Schedule the dialog to be shown after the current build phase
      Future.microtask(() {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => GameEndDialog(
              message: message,
              isOnlineGame: widget.isOnlineGame,
              isVsComputer: gameLogic is GameLogicVsComputer,
              player1: widget.player1,
              player2: widget.player2,
              onPlayAgain: () {
                if (widget.isOnlineGame) {
                  // For online games, go back to mode selection
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  // For local games, reset the board
                  setState(() {
                    _isShowingDialog = false;
                  });
                  
                  // Reset the game using the game logic's reset method
                  gameLogic.resetGame();
                  setState(() {});
                }
              },
            ),
          );
        }
      });
    }
  }

  Widget _buildGrid(List<String> board, bool isComputerTurn) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: List.generate(9, (index) {
        final value = board[index];
        return AbsorbPointer(
          absorbing: isComputerTurn,
          child: GridCell(
            key: ValueKey('cell_${index}_$value'),
            value: value,
            index: index,
            isVanishing: gameLogic.getNextToVanish() == index,
            onTap: () {
              setState(() {
                gameLogic.makeMove(index);
              });
              _handleGameEnd();
            },
          ),
        );
      }),
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
                  colors: [Colors.white, Color(0xFFF0F0F0)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  Builder(builder: (context) {
                    if (gameLogic is GameLogicOnline) {
                      return ValueListenableBuilder<String>(
                        valueListenable: (gameLogic as GameLogicOnline).turnNotifier,
                        builder: (context, _, __) {
                          return Text(
                            _getOnlinePlayerTurnText(gameLogic as GameLogicOnline),
                            style: GoogleFonts.pressStart2p(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      );
                    } else if (gameLogic is GameLogicVsComputer) {
                      return ValueListenableBuilder<List<String>>(
                        valueListenable: (gameLogic as GameLogicVsComputer).boardNotifier,
                        builder: (context, _, __) {
                          final playerName = _getCurrentPlayerName();
                          final turnText = playerName == 'You' ? 'Your turn' : "It's $playerName's turn";
                          return Text(
                            turnText,
                            style: GoogleFonts.pressStart2p(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      );
                    } else {
                      final playerName = _getCurrentPlayerName();
                      final turnText = playerName == 'You' ? 'Your turn' : "It's $playerName's turn";
                      return Text(
                        turnText,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                  }),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Builder(builder: (context) {
                      if (gameLogic is GameLogicVsComputer) {
                        return ValueListenableBuilder<List<String>>(
                          valueListenable: (gameLogic as GameLogicVsComputer).boardNotifier,
                          builder: (context, board, child) {
                            return _buildGrid(board, (gameLogic as GameLogicVsComputer).isComputerTurn);
                          },
                        );
                      } else if (gameLogic is GameLogicOnline) {
                        return ValueListenableBuilder<List<String>>(
                          valueListenable: (gameLogic as GameLogicOnline).boardNotifier,
                          builder: (context, board, child) {
                            return _buildGrid(
                              board, 
                              !(gameLogic as GameLogicOnline).isLocalPlayerTurn || _isConnecting
                            );
                          },
                        );
                      } else {
                        return _buildGrid(gameLogic.board, false);
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
          Footer(
            onHomePressed: () => Navigator.of(context).pop(),
            onGameOverPressed: () => setState(() => gameLogic.resetGame()),
          ),
        ],
      ),
    );
  }
}