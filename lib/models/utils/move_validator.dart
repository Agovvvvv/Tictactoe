import 'package:vanishingtictactoe/models/match.dart';

class MoveValidator {
  static bool validateMove(GameMatch match, int index, String playerSymbol) {
    if (match.status != 'active') return false;
    if (match.currentTurn != playerSymbol) return false;
    if (index < 0 || index >= 9) return false;
    if (match.board[index].isNotEmpty) return false;
    return true;
  }
}