import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vanishingtictactoe/screens/home_screen.dart';
import 'difficulty_selection_screen.dart';
import '../online/online_screen.dart';
import '../../providers/user_provider.dart';
import '../../providers/hell_mode_provider.dart';
import '../../widgets/mission_icon.dart';
import 'two_players_screen.dart';
import 'friendly_match_screen.dart';

enum GameMode {
  twoPlayers,
  vsComputer,
  online,
  friendlyMatch,
  hellMode,
}

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  void _handleModeSelection(GameMode mode) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);

    // If Hell Mode is selected, toggle it and return
    if (mode == GameMode.hellMode) {
      hellModeProvider.toggleHellMode();
      return;
    }

    switch (mode) {
      case GameMode.twoPlayers:
        if (context.mounted) {
          // Always go to the history screen regardless of hell mode status
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
      case GameMode.friendlyMatch:
        if (userProvider.user == null) {
          if (context.mounted) {
            _showLoginRequiredDialog(mode);
          }
        } else {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => mode == GameMode.online
                    ? const OnlineScreen()
                    : const FriendlyMatchScreen(),
              ),
            );
          }
        }
        break;
        
      case GameMode.hellMode:
        // This case is handled before the switch statement
        break;
    }
  }

  void _showLoginRequiredDialog(GameMode mode) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Rounded corners for the dialog
        ),
        elevation: 4, // Add a subtle shadow
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Add padding inside the dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure the dialog doesn't take up too much space
            crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
            children: [
              const Text(
                'Login Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, // Use a darker color for the title
                ),
              ),
              const SizedBox(height: 16), // Add spacing between title and content
              Text(
                mode == GameMode.online
                    ? 'You need to be logged in to play online.'
                    : 'You need to be logged in for friendly matches.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700], // Use a softer color for the content
                ),
              ),
              const SizedBox(height: 24), // Add spacing before the buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the end
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700], // Use a subtle color for the "Cancel" button
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Add padding
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8), // Add spacing between buttons
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Use a primary color for the "Login" button
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Add padding
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // Rounded corners for the button
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white, // White text for better contrast
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeScreen())),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.black,
              size: 30,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/account');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'Game Modes',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                  children: [
                    _buildModeSection(
                      title: 'Two Players',
                      description: 'Play against a friend on the same device',
                      icon: Icons.people,
                      mode: GameMode.twoPlayers,
                    ),
                    const SizedBox(height: 16),
                    _buildModeSection(
                      title: 'vs Computer',
                      description: 'Challenge our AI with different difficulty levels',
                      icon: Icons.computer,
                      mode: GameMode.vsComputer,
                    ),
                    const SizedBox(height: 16),
                    _buildModeSection(
                      title: 'Online',
                      description: 'Play against other players online',
                      icon: Icons.public,
                      mode: GameMode.online,
                    ),
                    const SizedBox(height: 16),
                    _buildModeSection(
                      title: 'Friendly Match',
                      description: 'Play with a friend using a match code',
                      icon: Icons.people_alt,
                      mode: GameMode.friendlyMatch,
                    ),
                    const SizedBox(height: 16),
                    _buildHellModeButton(),
                  ],
                ),
              ),
            ],
          ),
          // Mission icon in bottom right
          const Positioned(
            right: 16,
            bottom: 10,
            child: MissionIcon(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSection({
    required String title,
    required String description,
    required IconData icon,
    required GameMode mode,
  }) {
    final hellModeProvider = Provider.of<HellModeProvider>(context);
    // Apply fire styling if Hell Mode is active and this isn't the Hell Mode button itself
    final bool applyHellStyle = hellModeProvider.isHellModeActive && mode != GameMode.hellMode;
    
    return GestureDetector(
      onTap: () => _handleModeSelection(mode),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: applyHellStyle ? Colors.red.shade50 : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: applyHellStyle ? Colors.red.shade800 : Colors.grey[700],
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
                        color: applyHellStyle ? Colors.red.shade900 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: applyHellStyle ? Colors.red.shade700 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHellModeButton() {
    final hellModeProvider = Provider.of<HellModeProvider>(context);
    final isHellModeActive = hellModeProvider.isHellModeActive;
    
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _handleModeSelection(GameMode.hellMode),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: isHellModeActive ? Colors.red.shade900 : Colors.red.shade800,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.whatshot,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  isHellModeActive ? 'HELL ON' : 'HELL MODE',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}