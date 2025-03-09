import 'package:flutter/material.dart';
import 'package:vanishingtictactoe/logic/game_logic_2players.dart';
import 'package:vanishingtictactoe/screens/components/grid_cell.dart';

class GameBoardWidget extends StatelessWidget {
  final bool isInteractionDisabled;
  final Function(int) onCellTapped;
  final GameLogic gameLogic;

  const GameBoardWidget({
    super.key,
    required this.isInteractionDisabled,
    required this.onCellTapped,
    required this.gameLogic,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: gameLogic.boardNotifier,
      builder: (context, board, child) {
        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: List.generate(9, (index) {
            final value = board[index];
            return AbsorbPointer(
              absorbing: isInteractionDisabled,
              child: GridCell(
                key: ValueKey('cell_${index}_$value'),
                value: value,
                index: index,
                isVanishing: gameLogic.getNextToVanish() == index,
                onTap: () => onCellTapped(index),
              ),
            );
          }),
        );
      },
    );
  }
}