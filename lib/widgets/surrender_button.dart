import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SurrenderButtonWidget extends StatelessWidget {
  final VoidCallback onSurrender;

  const SurrenderButtonWidget({super.key, required this.onSurrender});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      bottom: 20,
      child: FloatingActionButton(
        onPressed: () {
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
                    onSurrender();
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
        backgroundColor: Colors.red,
        child: const Icon(Icons.flag),
      ),
    );
  }
}