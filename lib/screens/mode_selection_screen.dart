import 'package:flutter/material.dart';
import 'difficulty_selection_screen.dart';
import 'package:provider/provider.dart';
import 'online/matchmaking_screen.dart';
import '../providers/user_provider.dart';
import 'two_players_history_screen.dart';

enum GameMode {
  twoPlayers,
  vsComputer,
  online,
}

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {

  Widget _buildModeSection(String title, String description, IconData icon, GameMode mode) {
    return GestureDetector(
      onTap: () => _handleModeSelection(mode),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleModeSelection(GameMode mode) async {
    switch (mode) {
      case GameMode.twoPlayers:
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TwoPlayersHistoryScreen(),
            ),
          );
        }
        break;

      case GameMode.vsComputer:
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DifficultySelectionScreen(),
            ),
          );
        }
        break;

      case GameMode.online:
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.user == null) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Login Required'),
                content: const Text('You need to be logged in to play online.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MatchmakingScreen(),
              ),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return IconButton(
                icon: const Icon(
              Icons.account_circle,
              color: Colors.black,
              size: 30,
            ),
                onPressed: () {
              Navigator.pushNamed(context, '/account');
            },
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child:
            const Text(
              'Game Modes',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildModeSection(
                  'Two Players',
                  'Play against a friend on the same device',
                  Icons.people,
                  GameMode.twoPlayers,
                ),
                const SizedBox(height: 16),
                _buildModeSection(
                  'vs Computer',
                  'Challenge our AI with different difficulty levels',
                  Icons.computer,
                  GameMode.vsComputer,
                ),
                const SizedBox(height: 16),
                _buildModeSection(
                  'Online',
                  'Play against other players online',
                  Icons.public,
                  GameMode.online,
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
