import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'friendly_match_waiting_screen.dart';
import 'friendly_match_join_screen.dart';
import '../../models/utils/logger.dart';

class FriendlyMatchScreen extends StatefulWidget {
  const FriendlyMatchScreen({super.key});

  @override
  State<FriendlyMatchScreen> createState() => _FriendlyMatchScreenState();
}

class _FriendlyMatchScreenState extends State<FriendlyMatchScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friendly Match', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Play with a friend',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Create a match and share the code with a friend, or join a match with a code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              _buildOptionCard(
                title: 'Create Match',
                description: 'Generate a code and wait for a friend to join',
                icon: Icons.add_circle_outline,
                onTap: () => _handleCreateMatch(context),
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              _buildOptionCard(
                title: 'Join Match',
                description: 'Enter a code to join a friend\'s match',
                icon: Icons.login,
                onTap: () => _handleJoinMatch(context),
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Unfocus any active input before handling tap
            FocusManager.instance.primaryFocus?.unfocus();
            // Add slight delay to ensure proper event handling
            Future.delayed(const Duration(milliseconds: 50), onTap);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCreateMatch(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Debug user authentication status
    logger.i('User authenticated: ${userProvider.isLoggedIn}');
    if (userProvider.user != null) {
      logger.i('User ID: ${userProvider.user!.id}');
      logger.i('Username: ${userProvider.user!.username}');
    }
    
    if (userProvider.user == null) {
      _showLoginRequiredDialog();
      return;
    }

    // Generate a random 6-digit code
    final code = _generateMatchCode();
    
    // Unfocus any active input before navigation
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    
    // Add slight delay to ensure proper event handling
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendlyMatchWaitingScreen(matchCode: code),
        ),
      );
    });
  }

  void _handleJoinMatch(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) {
      _showLoginRequiredDialog();
      return;
    }
    
    // Unfocus any active input before navigation
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    
    // Add slight delay to ensure proper event handling
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FriendlyMatchJoinScreen(),
        ),
      );
    });
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You need to be logged in to play friendly matches.'),
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

  String _generateMatchCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // 6-digit code
  }
}
