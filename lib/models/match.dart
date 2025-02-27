import 'package:cloud_firestore/cloud_firestore.dart';

class OnlinePlayer {
  final String id;
  final String name;
  final String symbol;

  OnlinePlayer({
    required this.id,
    required this.name,
    required this.symbol,
  });

  factory OnlinePlayer.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      throw FormatException('Player data is null');
    }
    
    final id = data['id'] as String?;
    final name = data['name'] as String?;
    final symbol = data['symbol'] as String?;
    
    if (id == null || name == null || symbol == null) {
      throw FormatException('Missing required player data: id=$id, name=$name, symbol=$symbol');
    }
    
    return OnlinePlayer(
      id: id,
      name: name,
      symbol: symbol,
    );
  }
}

class GameMatch {
  final String id;
  final OnlinePlayer player1;
  final OnlinePlayer player2;
  final List<String> board;
  final String currentTurn;
  final String status;
  final String winner;
  final DateTime createdAt;
  final DateTime lastMoveAt;

  GameMatch({
    required this.id,
    required this.player1,
    required this.player2,
    required this.board,
    required this.currentTurn,
    required this.status,
    required this.winner,
    required this.createdAt,
    required this.lastMoveAt,
  });

  factory GameMatch.fromFirestore(Map<String, dynamic>? data, String matchId) {
    if (data == null) {
      throw FormatException('Match data is null');
    }
    
    try {
      final player1Data = data['player1'] as Map<String, dynamic>?;
      final player2Data = data['player2'] as Map<String, dynamic>?;
      final board = data['board'] as List?;
      final currentTurn = data['currentTurn'] as String?;
      final status = data['status'] as String?;
      final winner = data['winner'] as String?;
      
      if (player1Data == null || player2Data == null || board == null || 
          currentTurn == null || status == null || winner == null) {
        throw FormatException('Missing required match data');
      }
      
      return GameMatch(
        id: matchId,
        player1: OnlinePlayer.fromFirestore(player1Data),
        player2: OnlinePlayer.fromFirestore(player2Data),
        board: List<String>.from(board.map((e) => (e ?? '').toString())),
        currentTurn: currentTurn,
        status: status,
        winner: winner,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastMoveAt: (data['lastMoveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      throw FormatException('Error parsing match data: ${e.toString()}');
    }
  }

  bool get isCompleted => status == 'completed';
  bool get isDraw => isCompleted && winner.isEmpty;
}
