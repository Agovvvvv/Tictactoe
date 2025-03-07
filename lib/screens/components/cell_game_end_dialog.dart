import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CellGameEndDialog extends StatelessWidget {
  final String message;
  final VoidCallback onBackToMainBoard;

  const CellGameEndDialog({
    super.key,
    required this.message,
    required this.onBackToMainBoard,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Text(
        'Cell Game Over',
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
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              onBackToMainBoard();
            },
            child: Text(
              'Back to Main Board',
              textAlign: TextAlign.center,
              style: GoogleFonts.pressStart2p(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
