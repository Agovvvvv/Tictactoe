import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/player.dart';
import '../../logic/computer_player.dart';
import '../../models/user_level.dart';
import '../../providers/user_provider.dart';
import 'coin_flip_screen.dart';
import '../game/game_screen.dart';
import '../../logic/game_logic_2players.dart';
import '../../services/history/match_history_updates.dart';

class GameEndDialog extends StatelessWidget {
  final String message;
  final VoidCallback onPlayAgain;
  final VoidCallback? onBackToMenu;
  final bool isOnlineGame;
  final bool isVsComputer;
  final Player? player1;
  final Player? player2;
  final int? winnerMoves;
  final bool isSurrendered;
  final bool isCellGame;

  const GameEndDialog({
    super.key,
    required this.message,
    required this.onPlayAgain,
    this.onBackToMenu,
    this.isOnlineGame = false,
    this.isVsComputer = false,
    this.player1,
    this.player2,
    this.winnerMoves,
    this.isSurrendered = false,
    this.isCellGame = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Text(
        'Game Over',
        style: GoogleFonts.pressStart2p(
          fontSize: 20,
          color: Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: GoogleFonts.pressStart2p(
              fontSize: 16,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (!isCellGame) _buildXpEarnedWidget(context),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Center(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCellGame) 
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  if (onBackToMenu != null) {
                    onBackToMenu!();
                  }
                },
                child: Text(
                  'Back to Main Board',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              )
            else ...[  
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (!isOnlineGame && !isVsComputer && player1 != null && player2 != null) {
                    // For 2-player games, close dialog and show coin flip
                    Navigator.of(context).pop(); // Close game end dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => CoinFlipScreen(
                        player1: player1!,
                        player2: player2!,
                        onResult: (firstPlayer) {
                          // Create new game logic with the coin flip result
                          final isPlayer1First = firstPlayer == player1;
                          final gameLogic = GameLogic(
                            onGameEnd: (_) {},  // Will be handled by GameScreen
                            onPlayerChanged: () {},  // Will be handled by GameScreen
                            player1Symbol: player1!.symbol,
                            player2Symbol: player2!.symbol,
                            player1GoesFirst: isPlayer1First,
                          );
                          Navigator.of(context).pop(); // Close coin flip dialog
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => GameScreen(
                                player1: player1,
                                player2: player2,
                                logic: gameLogic,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  } else {
                    Navigator.of(context).pop(); // Close dialog
                    onPlayAgain();
                  }
                },
                child: Text(
                  isOnlineGame ? 'Back to Menu' : 'Play Again',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!isOnlineGame) ...[              
                const SizedBox(height: 10),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    // Trigger history update before going back
                    MatchHistoryUpdates.notifyUpdate();
                    
                    // Use onBackToMenu callback if provided, otherwise just pop
                    if (onBackToMenu != null) {
                      onBackToMenu!();
                    } else {
                      Navigator.of(context).pop(); // Go back to previous screen
                    }
                  },
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        ),
      ],
    );
  }
  
  Widget _buildXpEarnedWidget(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    // Don't show XP earned if:
    // - User is not logged in
    // - This is a 2-player game
    // - Player surrendered
    if (user == null || (!isOnlineGame && !isVsComputer) || isSurrendered) {
      return const SizedBox.shrink();
    }
    
    // Determine if the user won, drew, or lost
    bool isWin = false;
    bool isDraw = false;
    
    if (message.contains('win') || message.contains('Win')) {
      // Check if it's the user who won
      if (message.contains('You win')) {
        isWin = true;
      }
    } else if (message.contains('draw') || message.contains('Draw')) {
      isDraw = true;
    }
    
    // Check if this is a hell mode game
    final isHellMode = isVsComputer && message.contains('Hell');
    
    // Determine difficulty level from the message or player
    GameDifficulty difficulty = GameDifficulty.easy;
    if (isVsComputer) {
      if (message.toLowerCase().contains('medium')) {
        difficulty = GameDifficulty.medium;
      } else if (message.toLowerCase().contains('hard')) {
        difficulty = GameDifficulty.hard;
      }
      
      // If player2 is a ComputerPlayer, get difficulty directly
      if (player2 != null && player2 is ComputerPlayer) {
        difficulty = (player2 as ComputerPlayer).difficulty;
      }
    }
    
    // Calculate XP earned based on game outcome
    final xpEarned = UserLevel.calculateGameXp(
      isWin: isWin,
      isDraw: isDraw,
      movesToWin: isWin ? winnerMoves : null,
      level: user.userLevel.level,
      isHellMode: isHellMode,
      difficulty: difficulty,
    );
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'XP Earned',
                style: GoogleFonts.pressStart2p(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+$xpEarned',
                style: GoogleFonts.pressStart2p(
                  fontSize: 18,
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Show current level and progress
          Text(
            'Level ${user.userLevel.level}',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          // Simple progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: user.userLevel.progressPercentage / 100, // progressPercentage is now 0-100
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.userLevel.currentXp}/${user.userLevel.xpToNextLevel} XP to Level ${user.userLevel.level + 1}',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
