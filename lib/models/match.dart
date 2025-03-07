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
  final bool isRanked;
  final bool isHellMode;

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
    this.isRanked = false,
    this.isHellMode = false,
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
      final isRanked = data['isRanked'] as bool? ?? false;
      final isHellMode = data['isHellMode'] as bool? ?? false;
      
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
        isRanked: isRanked,
        isHellMode: isHellMode,
      );
    } catch (e) {
      throw FormatException('Error parsing match data: ${e.toString()}');
    }
  }

  bool get isCompleted => status == 'completed';
  bool get isDraw => isCompleted && winner.isEmpty;
  String get winnerId => winner; // The winner field already contains the winner's ID
  
  // Create a copy of this match with updated fields
  GameMatch copyWith({
    String? id,
    OnlinePlayer? player1,
    OnlinePlayer? player2,
    List<String>? board,
    String? currentTurn,
    String? status,
    String? winner,
    DateTime? createdAt,
    DateTime? lastMoveAt,
    bool? isRanked,
    bool? isHellMode,
  }) {
    return GameMatch(
      id: id ?? this.id,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      board: board ?? this.board,
      currentTurn: currentTurn ?? this.currentTurn,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      createdAt: createdAt ?? this.createdAt,
      lastMoveAt: lastMoveAt ?? this.lastMoveAt,
      isRanked: isRanked ?? this.isRanked,
      isHellMode: isHellMode ?? this.isHellMode,
    );
  }
}
