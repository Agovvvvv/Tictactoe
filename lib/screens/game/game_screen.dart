import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../logic/game_logic_2players.dart';
import '../../../logic/game_logic_vscomputer.dart';
import '../../../logic/game_logic_online.dart';
import '../../../logic/game_logic_vscomputer_hell.dart';
import '../../../models/player.dart';
import '../../../logic/computer_player.dart';
import '../components/grid_cell.dart';
import '../components/game_end_dialog.dart';
import 'package:provider/provider.dart';
import '../../services/history/local_match_history_service.dart';
import '../../services/history/match_history_updates.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/mission_provider.dart';
import '../../../providers/hell_mode_provider.dart';
import '../../models/utils/logger.dart';
import '../online/match_results_screen.dart';

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
            onGameEnd: (winner) => _handleGameEnd(winner),
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
            onGameEnd: (winner) => _handleGameEnd(winner),
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

    // For computer games, add a direct listener to the board changes
    if (gameLogic is GameLogicVsComputer) {
      final computerLogic = gameLogic as GameLogicVsComputer;
      computerLogic.boardNotifier.addListener(() {
        // Check for win after board updates
        if (!_isShowingDialog) {
          final winner = computerLogic.checkWinner();
          if (winner.isNotEmpty) {
            logger.i('Detected computer win from board listener: $winner');
            _handleGameEnd(winner);
          }
        }
      });
    }
    
    // Set up error handling and connection status for online games
    if (gameLogic is GameLogicOnline) {
      final onlineLogic = gameLogic as GameLogicOnline;
      
      // Override the onGameEnd handler from the source
      // Use reflection-based approach to work around the final field limitation
      try {
        // Hacky way to register our handler
        Future.delayed(Duration.zero, () {
          // Call our local handler when game ends
          onlineLogic.boardNotifier.addListener(() {
            if (onlineLogic.currentMatch?.status == 'completed') {
              // Use the winner from the match
              final winner = onlineLogic.currentMatch?.winner ?? '';
              if (winner.isNotEmpty) {
                logger.i('Detected game completion from board update. Winner: $winner');
                _handleGameEnd(winner);
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
    logger.i('Current game state - Player1(${widget.player1?.name}): ${gameLogic.player1Symbol}, Player2(${widget.player2?.name}): ${gameLogic.player2Symbol}, Current: ${gameLogic.currentPlayer}');
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
      logger.e('Error getting turn text: $e');
      return "Game in progress";
    }
  }

  bool _isShowingDialog = false;

  Future<void> _handleGameEnd([String? forcedWinner, bool isSurrendered = false]) async {
    logger.i('_handleGameEnd called with forcedWinner: $forcedWinner, isSurrendered: $isSurrendered');
    
    if (_isShowingDialog) {
      logger.i('Dialog already showing, ignoring game end call');
      return;
    }
    
    // Use the forced winner if provided, otherwise check the game state
    String winner = forcedWinner ?? '';
    if (winner.isEmpty) {
      winner = gameLogic.checkWinner();
      logger.i('Checked winner from game logic: $winner');
    }
    
    // For computer games, ensure we detect a full board as a draw
    bool isDraw = winner == 'draw' || (winner.isEmpty && !gameLogic.board.contains(''));
    
    // For computer games, explicitly check the board state
    if (gameLogic is GameLogicVsComputer) {
      // Log the current board state for debugging
      logger.i('Current board state: ${gameLogic.board}');
      
      // Double-check the winner one more time
      if (winner.isEmpty) {
        winner = gameLogic.checkWinner();
        logger.i('Re-checked winner for computer game: $winner');
      }
      
      // If we have a forced winner from the computer logic, use it
      if (forcedWinner != null && forcedWinner.isNotEmpty) {
        logger.i('Using forced winner from computer logic: $forcedWinner');
        winner = forcedWinner;
        isDraw = false;
      }
    }
    
    logger.i('Game end handler called with winner: $winner, isDraw: $isDraw');
    
    // If we're in an online game, check the game status directly
    if (gameLogic is GameLogicOnline) {
      final onlineLogic = gameLogic as GameLogicOnline;
      final match = onlineLogic.currentMatch;
      
      // If the match is completed but we don't have a winner yet, use the match winner
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
      // Don't set _isShowingDialog here - will set it just before showing the dialog
      logger.i('Game end detected, preparing to show dialog');
      String winnerName;
      bool isHumanWinner = false;
      
      if (gameLogic is GameLogicVsComputer) {
        final vsComputer = gameLogic as GameLogicVsComputer;
        isHumanWinner = winner == vsComputer.player1Symbol;
        final player1Name = widget.player1?.name ?? 'Player 1';
        winnerName = isHumanWinner ? player1Name : 'Computer';
      } else if (gameLogic is GameLogicOnline) {
        final online = gameLogic as GameLogicOnline;
        // Handle draw case specifically
        if (isDraw || winner == 'draw') {
          winnerName = 'Nobody';
        } else {
          // Get the winner's name from the match data
          final match = online.currentMatch;
          if (match != null && match.winner.isNotEmpty) {
            // Find the player whose ID matches the winner ID
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
        // Local two-player game
        final player1Name = widget.player1?.name ?? 'Player 1';
        final player2Name = widget.player2?.name ?? 'Player 2';
        winnerName = winner == 'X' ? player1Name : player2Name;
        
        // Save match result to local history - ONLY for regular 2-player games (not computer games)
        if (!isDraw && (gameLogic is! GameLogicVsComputer)) {
          final player1WentFirst = gameLogic.player1Symbol == 'X';
          logger.i('Saving match history for 2-player game - Type check: ${gameLogic.runtimeType}');
          
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
        } else {
          logger.i('Skipping match history save for 2-player section - isDraw: $isDraw, isComputer: ${gameLogic is GameLogicVsComputer}');
        }
      }
      // Create a personalized message based on game type and outcome
      String message;
      
      if (isSurrendered) {
        message = winnerName == 'Computer' ? 'You surrendered!' : '$winnerName wins by surrender!';
      } else if (isDraw) {
        message = 'It\'s a draw!';
      } else if (gameLogic is GameLogicOnline) {
        final online = gameLogic as GameLogicOnline;
        final match = online.currentMatch;
        if (match != null) {
          // Compare player IDs to determine if local player won
          final localPlayerId = online.localPlayerId;
          final isLocalPlayerWinner = match.winner == localPlayerId;
          
          if (isLocalPlayerWinner) {
            // For the winning player, show a more personal message
            message = 'You win!';
          } else {
            // For the losing player, show the winner's name
            message = '$winnerName wins!';
          }
        } else {
          message = '$winnerName wins!';
        }
      } else {
        // For local games or vs computer, just show the winner's name
        message = isHumanWinner? 'You win!' : 'Computer wins!';
      }
      
      // Get winner's moves count
      int? winnerMoves;
      if (!isDraw) {
        winnerMoves = winner == 'X' ? gameLogic.xMoveCount : gameLogic.oMoveCount;
      }
      
      // Update game stats if it's a computer game
      logger.i('Game type check: ${gameLogic.runtimeType}');
      if (gameLogic is GameLogicVsComputer) {
        logger.i('Handling computer game end - winner: $winner, isDraw: $isDraw');
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final missionProvider = Provider.of<MissionProvider>(context, listen: false);
        final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
        
        // Determine if this is a Hell Mode game
        final isHellMode = gameLogic is GameLogicVsComputerHell || hellModeProvider.isHellModeActive;
        
        // Get difficulty if available
        GameDifficulty? difficulty;
        if (widget.player2 is ComputerPlayer) {
          final computerPlayer = widget.player2 as ComputerPlayer;
          difficulty = computerPlayer.difficulty;
        }
        
        if (userProvider.user != null) {
          // Update user stats
          userProvider.updateGameStats(
            isWin: isDraw ? false : isHumanWinner,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isHumanWinner ? winnerMoves : null), // Only count human wins
            isOnline: false,
            isFriendlyMatch: isSurrendered, // Set friendly match to true if surrendered to skip XP
          );
          
          // Track mission progress only if not surrendered
          if (!isSurrendered) {
            missionProvider.trackGamePlayed(
              isHellMode: isHellMode,
              isWin: isHumanWinner,
              difficulty: difficulty,
            );
          }
          
          logger.i('Game stats updated - Winner: ${isDraw ? 'Draw' : (isHumanWinner ? 'Human' : 'Computer')}, Winner Moves: $winnerMoves, Hell Mode: $isHellMode');
        }
      } else if (gameLogic is GameLogicOnline) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final missionProvider = Provider.of<MissionProvider>(context, listen: false);
        final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
        
        // Determine if this is a Hell Mode game
        final isHellMode = hellModeProvider.isHellModeActive;
        
        if (userProvider.user != null) {
          final online = gameLogic as GameLogicOnline;
          final isWin = online.localPlayerId == online.currentMatch?.winner;
          
          // Update user stats
          userProvider.updateGameStats(
            isWin: isDraw ? false : isWin,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isWin ? winnerMoves : null), // Only count local player wins
            isOnline: true,
            isFriendlyMatch: isSurrendered, // No XP if surrendered
          );
          
          // Track mission progress for online games if not surrendered
          if (!isSurrendered) {
            missionProvider.trackGamePlayed(
              isHellMode: isHellMode,
              isWin: isWin,
              difficulty: null, // Online games don't have difficulty
            );
          }
          
          logger.i('Game stats updated - Winner: ${isDraw ? 'Draw' : (isWin ? 'Local Player' : 'Opponent')}, Winner Moves: $winnerMoves, Hell Mode: $isHellMode');
        }
      } else if (gameLogic is! GameLogicVsComputer) {
        // This is a regular 2-player game (not vs computer)
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final missionProvider = Provider.of<MissionProvider>(context, listen: false);
        final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
        
        // Determine if this is a Hell Mode game
        final isHellMode = hellModeProvider.isHellModeActive;
        
        if (userProvider.user != null) {
          // For 2-player games, we still update stats but don't award XP
          final isWin = winner == userProvider.user!.username;
          
          // Update user stats
          userProvider.updateGameStats(
            isWin: isDraw ? false : isWin,
            isDraw: isDraw,
            movesToWin: isDraw ? null : (isWin ? winnerMoves : null),
            isOnline: false,
            isFriendlyMatch: true, // 2-player games don't award XP
          );
          
          // Track mission progress for 2-player games if not surrendered
          if (!isSurrendered) {
            missionProvider.trackGamePlayed(
              isHellMode: isHellMode,
              isWin: isWin,
              difficulty: null, // 2-player games don't have difficulty
            );
          }
          
          logger.i('Game stats updated for 2-player game - No XP awarded, Hell Mode: $isHellMode');
        }
      }
      
      // Schedule the dialog to be shown after the current build phase
      logger.i('Scheduling dialog to be shown');
      
      // For ranked online matches, navigate to the match results screen
      if (widget.isOnlineGame && gameLogic is GameLogicOnline) {
        final onlineLogic = gameLogic as GameLogicOnline;
        final match = onlineLogic.currentMatch;
        final isRankedMatch = match?.isRanked ?? false;
        final isHellMode = match?.isHellMode ?? false;
        
        if (match != null && isRankedMatch) {
          // Get the user provider to access rank information
          final userProvider = Provider.of<UserProvider>(context, listen: false);

          await userProvider.refreshUserData(forceServerRefresh: true);

          final user = userProvider.user;
          
          if (user != null) {
            // Get rank information
            final int? rankPointsChange = user.lastRankPointsChange;
            final String? previousDivision = user.previousDivision;
            final String? newDivision = user.fullRank;
            
            
            logger.i('Navigating to match results screen with rank changes: $rankPointsChange, $previousDivision -> $newDivision');
            
            // Ensure resources are properly disposed before navigating away
            onlineLogic.dispose();
            
            // Navigate to match results screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => MatchResultsScreen(
                  match: match,
                  isRanked: isRankedMatch,
                  isHellMode: isHellMode,
                  rankPointsChange: rankPointsChange,
                  previousDivision: previousDivision,
                  newDivision: newDivision,
                ),
              ),
            );
            return;
          }
        }
      }
      
      // For non-ranked matches or if there was an issue getting rank info, show the regular dialog
      logger.i('Will show dialog in 100ms');
      Future.delayed(Duration(milliseconds: 100), () {
        // Only proceed if we're still mounted and dialog isn't showing
        if (mounted && !_isShowingDialog) {
          logger.i('Now showing dialog');
          _isShowingDialog = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => GameEndDialog(
                  isSurrendered: isSurrendered,
                  message: message,
                  isOnlineGame: widget.isOnlineGame,
                  isVsComputer: gameLogic is GameLogicVsComputer,
                  player1: widget.player1,
                  player2: widget.player2,
                  winnerMoves: winnerMoves,
                  onPlayAgain: () {
                    if (widget.isOnlineGame) {
                      // For online games, go back to mode selection
                      // Ensure resources are properly disposed before navigating away
                      if (gameLogic is GameLogicOnline) {
                        (gameLogic as GameLogicOnline).dispose();
                      }
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
              ).then((_) {
                // Reset dialog showing flag when dialog is closed
                _isShowingDialog = false;
              });
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
              
              // Always check for game end after a move, both for online and local games
              // This ensures the dialog is shown in all cases
              _handleGameEnd();
            },
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    // Dispose of game logic resources when navigating away
    if (gameLogic is GameLogicOnline) {
      (gameLogic as GameLogicOnline).dispose();
    }
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return PopScope(
    canPop: true,
    onPopInvokedWithResult: (didPop, result) async {
      // Ensure resources are properly disposed before navigating back
      if (gameLogic is GameLogicOnline) {
        (gameLogic as GameLogicOnline).dispose();
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
            ],
          ),
          // Surrender button in the bottom left
          Positioned(
            left: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: () {
                // Show surrender confirmation dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Surrender?',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to surrender? You will not receive XP for this game.',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.roboto(),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Handle surrender
                          if (gameLogic is GameLogicVsComputer) {
                            // In computer games, computer wins
                            _handleGameEnd(
                              (gameLogic as GameLogicVsComputer).computerPlayer.symbol,
                              true
                            );
                          } else if (gameLogic is! GameLogicOnline) {
                            // In 2-player games, current player's opponent wins
                            final winner = gameLogic.currentPlayer == 'X' ? 'O' : 'X';
                            _handleGameEnd(winner, true);
                          }
                        },
                        child: Text(
                          'Surrender',
                          style: GoogleFonts.roboto(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              backgroundColor: Colors.red, // Red color for surrender
              child: const Icon(Icons.flag), // Flag icon for surrender
            ),
          ),
        ],
      ),
    ),
  );
}
}