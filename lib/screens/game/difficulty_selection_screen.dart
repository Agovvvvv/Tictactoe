import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/player.dart';
import '../../logic/computer_player.dart';
import '../../logic/game_logic_vscomputer.dart';
import '../../logic/game_logic_vscomputer_hell.dart';
import 'game_screen.dart';
import 'Hell/hell_game_screen.dart';
import '../../providers/user_provider.dart';
import '../../providers/hell_mode_provider.dart';
import '../../services/history/match_history_service.dart';
import '../../models/utils/logger.dart';
import '../../widgets/mission_icon.dart';

class DifficultySelectionScreen extends StatefulWidget {
  const DifficultySelectionScreen({super.key});

  @override
  State<DifficultySelectionScreen> createState() => _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> {
  GameDifficulty _selectedDifficulty = GameDifficulty.easy;
  final MatchHistoryService _matchHistory = MatchHistoryService();

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
    };
  }

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

  void _startGame(GameDifficulty difficulty) {
    const playerSymbol = 'X';
    const computerSymbol = 'O';

    final computerPlayer = ComputerPlayer(
      difficulty: difficulty,
      computerSymbol: computerSymbol,
      playerSymbol: playerSymbol,
      name: 'Computer (${_getDifficultyName(difficulty)})',
    );
    
    // Check if hell mode is active
    final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
    final isHellModeActive = hellModeProvider.isHellModeActive;
    
    // Create the appropriate game logic based on the game mode
    final gameLogic = isHellModeActive
      ? GameLogicVsComputerHell(
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

              await _matchHistory.saveMatchResult(
                userId: userProvider.user!.id,
                difficulty: difficulty,
                result: result,
              );
              logger.i('Match saved: $result');
            }
          },
          computerPlayer: computerPlayer,
          humanSymbol: playerSymbol,
        )
      : GameLogicVsComputer(
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

              await _matchHistory.saveMatchResult(
                userId: userProvider.user!.id,
                difficulty: difficulty,
                result: result,
              );
              logger.i('Match saved: $result');
            }
          },
          computerPlayer: computerPlayer,
          humanSymbol: playerSymbol,
        );
    
    // Create player objects
    final player1 = Player(name: 'You', symbol: playerSymbol);
    // Use the computerPlayer as player2 (it's already a Player since it extends Player)
    final player2 = computerPlayer;

    // Navigate to the appropriate screen based on hell mode status
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isHellModeActive
          ? HellGameScreen(
              player1: player1,
              player2: player2,
              logic: gameLogic,
            )
          : GameScreen(
              player1: player1,
              player2: player2,
              logic: gameLogic,
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
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: MissionIcon(),
          ),
        ],
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _getDifficultyName(_selectedDifficulty),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Match History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      isLoggedIn
                        ? _buildMatchHistorySection(userProvider)
                        : _buildLoginPrompt(defaultMessage),
                      const Spacer(),
                      _buildPlayButton(),
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

  Widget _buildDifficultySelector() {
    return Card(
      margin: const EdgeInsets.all(20),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white, // Set card background to white
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Choose your challenge level',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
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
                            color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.2),
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
      ),
    );
  }

  Widget _buildMatchHistorySection(UserProvider userProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white, // Set card background to white
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(String message) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/login'),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white, // Set card background to white
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.blue,
              height: 1.5,
              // Removed underline
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Consumer<HellModeProvider>(
      builder: (context, hellModeProvider, child) {
        final isHellModeActive = hellModeProvider.isHellModeActive;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startGame(_selectedDifficulty),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isHellModeActive ? Colors.red.shade900 : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isHellModeActive)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.whatshot, color: Colors.yellow),
                    ),
                  Text(
                    isHellModeActive ? 'PLAY HELL MODE' : 'Play',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isHellModeActive ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  }
