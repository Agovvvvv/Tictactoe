import 'package:flutter/material.dart';
import '../models/player.dart';
import '../logic/computer_player.dart';
import '../logic/game_logic_vscomputer.dart';
import 'game_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/match_history_service.dart';

class DifficultySelectionScreen extends StatefulWidget {
  const DifficultySelectionScreen({super.key});

  @override
  State<DifficultySelectionScreen> createState() => _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> {
  // Initialize with Easy difficulty selected by default
  GameDifficulty _selectedDifficulty = GameDifficulty.easy;
  final MatchHistoryService _matchHistory = MatchHistoryService();

  String _getMatchHistoryText(AsyncSnapshot<Map<String, int>> snapshot) {
    if (!snapshot.hasData) return 'Loading...';
    if (snapshot.hasError) return 'Error loading match history';

    final stats = snapshot.data!;
    final wins = stats['win'] ?? 0;
    final losses = stats['loss'] ?? 0;
    final draws = stats['draw'] ?? 0;
    final total = wins + losses + draws;

    if (total == 0) return 'No matches played yet';

    return '''Matches played: $total
Wins: $wins
Losses: $losses
Draws: $draws
Win rate: ${(wins * 100 / total).toStringAsFixed(1)}%''';
  }

  // List of all available difficulties
  final List<GameDifficulty> _difficulties = [
    GameDifficulty.easy,
    GameDifficulty.medium,
    GameDifficulty.hard,
  ];

  String _getDifficultyName(GameDifficulty difficulty) {
    return switch (difficulty) {
      GameDifficulty.easy => 'Easy',
      GameDifficulty.medium => 'Medium',
      GameDifficulty.hard => 'Hard',
      GameDifficulty.impossible => 'Impossible',
    };
  }

  Widget _buildDifficultySelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Center(
            child: Text(
              'Choose your challenge level',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _difficulties.map((difficulty) {
              final isSelected = _selectedDifficulty == difficulty;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: difficulty != _difficulties.last ? 12 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDifficulty = difficulty),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getDifficultyName(difficulty),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _startGame(GameDifficulty difficulty) {
    const playerSymbol = 'X';
    const computerSymbol = 'O';

    final computerPlayer = ComputerPlayer(
      difficulty: difficulty,
      computerSymbol: computerSymbol,
      playerSymbol: playerSymbol,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          player1: Player(name: 'You', symbol: playerSymbol),
          player2: Player(
            name: 'Computer (${_getDifficultyName(difficulty)})',
            symbol: computerSymbol,
          ),
          logic: GameLogicVsComputer(
            onGameEnd: (winner) async {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              if (userProvider.user != null) {
                String result;
                if (winner.isEmpty) {
                  result = 'draw';
                } else if (winner == playerSymbol) {
                  result = 'win';
                } else {
                  result = 'loss';
                }

                // Only update match history, let GameScreen handle stats
                await _matchHistory.saveMatchResult(
                  userId: userProvider.user!.id,
                  difficulty: difficulty,
                  result: result,
                );
                print('Match saved: $result');
              }
            },
            computerPlayer: computerPlayer,
            humanSymbol: playerSymbol,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Select Difficulty',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final isLoggedIn = userProvider.user != null;
          final defaultMessage = isLoggedIn 
              ? 'No matches played yet'
              : 'Log in to see match history';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDifficultySelector(),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _getDifficultyName(_selectedDifficulty),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Match History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      isLoggedIn
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: StreamBuilder<Map<String, int>>(
                              stream: _matchHistory.getMatchStats(
                                userId: userProvider.user!.id,
                                difficulty: _selectedDifficulty,
                              ),
                              builder: (context, snapshot) {
                                return Text(
                                  _getMatchHistoryText(snapshot),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                          )
                        : GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/login'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                defaultMessage,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _startGame(_selectedDifficulty),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Play',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
