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
    
    final id = data['id'] as String? ?? 'unknown';
    final name = data['name'] as String? ?? 'Player';
    final symbol = data['symbol'] as String? ?? 'X';
    
    // We'll still create a player even if some data is missing
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
    this.isHellMode = false,
  });

  factory GameMatch.fromFirestore(Map<String, dynamic>? data, String matchId) {
    if (data == null) {
      throw FormatException('Match data is null');
    }
    
    try {
      // Extract data with fallbacks for required fields
      final player1Data = data['player1'] as Map<String, dynamic>?;
      final player2Data = data['player2'] as Map<String, dynamic>?;
      
      // Handle missing player data with more graceful fallbacks
      var player1;
      var player2;
      
      try {
        player1 = OnlinePlayer.fromFirestore(player1Data);
      } catch (e) {
        // Create a default player if data is missing
        player1 = OnlinePlayer(
          id: 'unknown_player1',
          name: 'Player 1',
          symbol: 'X',
        );
      }
      
      try {
        player2 = OnlinePlayer.fromFirestore(player2Data);
      } catch (e) {
        // Create a default player if data is missing
        player2 = OnlinePlayer(
          id: 'unknown_player2',
          name: 'Player 2',
          symbol: 'O',
        );
      }
      
      // Extract other fields with fallbacks
      final List<dynamic>? rawBoard = data['board'] as List?;
      final List<String> board = rawBoard != null 
          ? List<String>.from(rawBoard.map((e) => (e ?? '').toString()))
          : List.filled(9, '');
          
      final String currentTurn = (data['currentTurn'] as String?) ?? 'X';
      final String status = (data['status'] as String?) ?? 'active';
      final String winner = (data['winner'] as String?) ?? '';
      final bool isHellMode = data['isHellMode'] as bool? ?? false;
      
      // Ensure board has exactly 9 cells
      final List<String> validatedBoard = board.length == 9 
          ? board 
          : List.filled(9, '');
      
      return GameMatch(
        id: matchId,
        player1: player1,
        player2: player2,
        board: validatedBoard,
        currentTurn: currentTurn,
        status: status,
        winner: winner,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastMoveAt: (data['lastMoveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      isHellMode: isHellMode ?? this.isHellMode,
    );
  }
}
