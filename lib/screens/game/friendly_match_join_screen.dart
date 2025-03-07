import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'game_screen.dart';
import '../../logic/game_logic_online.dart';
import '../../services/matches/friendly_match_service.dart';
import '../../models/utils/logger.dart';

class FriendlyMatchJoinScreen extends StatefulWidget {
  const FriendlyMatchJoinScreen({super.key});

  @override
  State<FriendlyMatchJoinScreen> createState() => _FriendlyMatchJoinScreenState();
}

class _FriendlyMatchJoinScreenState extends State<FriendlyMatchJoinScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FriendlyMatchService _matchService = FriendlyMatchService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinMatch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a match code';
        _isLoading = false;
      });
      return;
    }

    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() {
        _errorMessage = 'Invalid match code format';
        _isLoading = false;
      });
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) {
      setState(() {
        _errorMessage = 'You need to be logged in to join a match';
        _isLoading = false;
      });
      return;
    }

    try {
      // Check if match exists
      final matchData = await _matchService.getMatch(code);
      
      if (matchData == null) {
        setState(() {
          _errorMessage = 'Match not found';
          _isLoading = false;
        });
        return;
      }

      if (matchData['guestId'] != null) {
        setState(() {
          _errorMessage = 'Match already has a player';
          _isLoading = false;
        });
        return;
      }

      // Join the match - this now returns the active match ID
      final activeMatchId = await _matchService.joinMatch(
        matchCode: code,
        guestId: userProvider.user!.id,
        guestName: userProvider.user!.username,
      );

      // Navigate to game using online game logic
      if (mounted) {
        // Create online game logic for the friendly match
        final gameLogic = GameLogicOnline(
          onGameEnd: (winner) {
            // The actual game end handling will be done by the GameScreen
            logger.i('Game ended with winner: $winner. GameScreen will handle the dialog.');
          },
          onPlayerChanged: () {},
          localPlayerId: userProvider.user!.id,
        );

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
    } catch (e) {
      setState(() {
        _errorMessage = 'Error joining match: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Match', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.login,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter Match Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask your friend for the 6-digit code',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Match Code',
                hintText: '123456',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.numbers),
                errorText: _errorMessage,
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _joinMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Join Match',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
