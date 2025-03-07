import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../logic/game_logic_online.dart';
import 'game_screen.dart';
import '../../services/matches/friendly_match_service.dart';
import '../../models/utils/logger.dart';

class FriendlyMatchWaitingScreen extends StatefulWidget {
  final String matchCode;

  const FriendlyMatchWaitingScreen({
    super.key,
    required this.matchCode,
  });

  @override
  State<FriendlyMatchWaitingScreen> createState() => _FriendlyMatchWaitingScreenState();
}

class _FriendlyMatchWaitingScreenState extends State<FriendlyMatchWaitingScreen> {
  bool _isCodeCopied = false;
  late FriendlyMatchService _matchService;
  StreamSubscription? _matchSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _matchService = FriendlyMatchService();
    _setupMatch();
  }

  Future<void> _setupMatch() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to create a match')),
        );
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Log user info for debugging
      logger.i('Creating match with user ID: ${userProvider.user!.id}');
      logger.i('User name: ${userProvider.user!.username}');
      
      // Create the match in Firebase
      await _matchService.createMatch(
        matchCode: widget.matchCode,
        hostId: userProvider.user!.id,
        hostName: userProvider.user!.username,
      );

      // Listen for a player to join
      _matchSubscription = _matchService.listenForMatchUpdates(widget.matchCode).listen((matchData) {
        if (matchData != null && matchData['guestId'] != null) {
          // A player has joined, start the game
          _navigateToGame(matchData);
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting up match: ${e.toString()}')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _navigateToGame(Map<String, dynamic> matchData) {
    _matchSubscription?.cancel();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;
    
    if (currentUser == null || !mounted) return;

    // Get the active match ID
    final activeMatchId = matchData['activeMatchId'];
    if (activeMatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active match found')),
      );
      return;
    }

    // Create online game logic for the friendly match
    final gameLogic = GameLogicOnline(
      onGameEnd: (winner) {
        // The actual game end handling will be done by the GameScreen
        logger.i('Game ended with winner: $winner. GameScreen will handle the dialog.');
      },
      onPlayerChanged: () {},
      localPlayerId: currentUser.id,
    );

    // Navigate to the game screen with online logic
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          isOnlineGame: true,
          logic: gameLogic,
        ),
      ),
    );

    // Join the active match
    gameLogic.joinMatch(activeMatchId);
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting for Player', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people_alt,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Waiting for a player to join',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Share this code with a friend to start playing',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.matchCode,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              _isCodeCopied ? Icons.check : Icons.copy,
                              color: _isCodeCopied ? Colors.green : Colors.grey,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.matchCode));
                              setState(() => _isCodeCopied = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied to clipboard')),
                              );
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() => _isCodeCopied = false);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        _matchSubscription?.cancel();
                        _matchService.deleteMatch(widget.matchCode);
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
