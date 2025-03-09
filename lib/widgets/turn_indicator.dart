import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vanishingtictactoe/logic/game_logic_2players.dart';
import 'package:vanishingtictactoe/logic/game_logic_online.dart';
import 'package:vanishingtictactoe/models/player.dart';

class TurnIndicatorWidget extends StatelessWidget {
  final GameLogic gameLogic;
  final Player? player1;
  final Player? player2;
  final bool isConnecting;
  final String Function(Player?, Player?) getCurrentPlayerName;
  final String Function(GameLogicOnline, bool) getOnlinePlayerTurnText;

  const TurnIndicatorWidget({
    super.key,
    required this.gameLogic,
    required this.player1,
    required this.player2,
    required this.isConnecting,
    required this.getCurrentPlayerName,
    required this.getOnlinePlayerTurnText,
  });

  @override
  Widget build(BuildContext context) {
    if (gameLogic is GameLogicOnline) {
      return ValueListenableBuilder<String>(
        valueListenable: (gameLogic as GameLogicOnline).turnNotifier,
        builder: (context, _, __) {
          return Text(
            getOnlinePlayerTurnText(gameLogic as GameLogicOnline, isConnecting),
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
      // For both computer and local two-player games, listen to boardNotifier
      return ValueListenableBuilder<List<String>>(
        valueListenable: gameLogic.boardNotifier,
        builder: (context, _, __) {
          final playerName = getCurrentPlayerName(player1, player2);
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
    }
  }
}