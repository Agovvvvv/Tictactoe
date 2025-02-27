import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/player.dart';
import 'coin_flip_screen.dart';

class GameEndDialog extends StatelessWidget {
  final String message;
  final VoidCallback onPlayAgain;
  final bool isOnlineGame;
  final bool isVsComputer;
  final Player? player1;
  final Player? player2;

  const GameEndDialog({
    super.key,
    required this.message,
    required this.onPlayAgain,
    this.isOnlineGame = false,
    this.isVsComputer = false,
    this.player1,
    this.player2,
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
      content: Text(
        message,
        style: GoogleFonts.pressStart2p(
          fontSize: 16,
          color: Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Center(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                        Navigator.of(context).pop(); // Close coin flip dialog
                        onPlayAgain(); // Reset the board
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
                  Navigator.of(context).pop(); // Go back to previous screen
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
        ),
        ),
      ],
    );
  }
}
