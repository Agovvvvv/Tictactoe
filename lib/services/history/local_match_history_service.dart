import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalMatchHistoryService {
  static const String _key = 'two_player_matches';

  Future<void> saveMatch({
    required String player1,
    required String player2,
    required String winner,
    required bool player1WentFirst,
    String? player1Symbol,
    String? player2Symbol,
    bool isHellMode = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> matches = prefs.getStringList(_key) ?? [];
    
    // If player2 went first, swap the order in the display
    final displayPlayer1 = player1WentFirst ? player1 : player2;
    final displayPlayer2 = player1WentFirst ? player2 : player1;
    final displayPlayer1Symbol = player1WentFirst ? (player1Symbol ?? 'X') : (player2Symbol ?? 'O');
    final displayPlayer2Symbol = player1WentFirst ? (player2Symbol ?? 'O') : (player1Symbol ?? 'X');
    
    final match = {
      'player1': displayPlayer1,
      'player2': displayPlayer2,
      'winner': winner,
      'player1_symbol': displayPlayer1Symbol,
      'player2_symbol': displayPlayer2Symbol,
      'timestamp': DateTime.now().toIso8601String(),
      'is_hell_mode': isHellMode,
    };

    matches.insert(0, jsonEncode(match)); // Add new match at the beginning
    
    // Filter out matches older than 5 days
    final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
    matches = matches.where((matchJson) {
      final matchData = jsonDecode(matchJson) as Map<String, dynamic>;
      final timestamp = DateTime.parse(matchData['timestamp'] as String);
      return timestamp.isAfter(fiveDaysAgo);
    }).toList();

    await prefs.setStringList(_key, matches);
  }

  Future<List<Map<String, dynamic>>> getRecentMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final matches = prefs.getStringList(_key) ?? [];

    return matches
        .map((match) => Map<String, dynamic>.from(jsonDecode(match)))
        .toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
