import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/match.dart';
import '../../providers/user_provider.dart';
import 'online_screen.dart';
import '../../models/utils/logger.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../models/utils/app_them.dart';

// Helper for conditional logging
void logInfo(String message) {
  if (foundation.kDebugMode) {
    logger.i(message);
  }
}

class MatchResultsScreen extends StatefulWidget {
  final GameMatch match;
  final bool isHellMode;

  const MatchResultsScreen({
    super.key,
    required this.match,
    this.isHellMode = false,
  });

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen>
    with TickerProviderStateMixin {
  FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Animation for the  change card
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Initialize animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.user?.id;

    // Determine if current user is player1 or player2
    final isPlayer1 = widget.match.player1.id == userId;
    final localPlayer = isPlayer1 ? widget.match.player1 : widget.match.player2;
    final opponent = isPlayer1 ? widget.match.player2 : widget.match.player1;

    // Determine if the local player won
    final String winnerId = widget.match.winnerId;
    final bool isWinner = winnerId == userId;
    final bool isDraw = widget.match.isDraw;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Match Results',
            style: TextStyle(
              color: widget.isHellMode ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: widget.isHellMode ? AppTheme.hellModeColor : Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _navigateToOnlineScreen(),
              color: widget.isHellMode ? Colors.white : Colors.black,
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildResultHeader(isWinner, isDraw),
                const SizedBox(height: 30),
                _buildPlayersInfo(localPlayer, opponent),
                const SizedBox(height: 40),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(bool isWinner, bool isDraw) {
    String resultText;
    Color resultColor;
    IconData resultIcon;

    if (isDraw) {
      resultText = "It's a Draw!";
      resultColor = AppTheme.drawColor;
      resultIcon = Icons.balance;
    } else if (isWinner) {
      resultText = "Victory!";
      resultColor = AppTheme.victoryColor;
      resultIcon = Icons.emoji_events;
    } else {
      resultText = "Defeat";
      resultColor = AppTheme.defeatColor;
      resultIcon = Icons.sentiment_dissatisfied;
    }

    return Column(
      children: [
        Icon(
          resultIcon,
          size: 80,
          color: resultColor,
        ),
        const SizedBox(height: 16),
        Text(
          resultText,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: resultColor,
          ),
        ),
        if (widget.isHellMode)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.hellModeColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.whatshot, color: AppTheme.hellModeColor, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'HELL MODE',
                    style: TextStyle(
                      color: AppTheme.hellModeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayersInfo(OnlinePlayer localPlayer, OnlinePlayer opponent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildPlayerCard(
          localPlayer.name,
          localPlayer.symbol,
          'You',
          Colors.blue.shade100,
          Colors.blue,
        ),
        const Text(
          'VS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        _buildPlayerCard(
          opponent.name,
          opponent.symbol,
          'Opponent',
          Colors.red.shade100,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildPlayerCard(
    String name,
    String symbol,
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.3, // Responsive width
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: textColor, width: 2),
            ),
            child: Center(
              child: Text(
                symbol,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActionButtons() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _navigateToOnlineScreen,
        icon: const Icon(Icons.home),
        label: const Text(AppTheme.backToLobbyLabel),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _navigateToOnlineScreen() async {
    if (!mounted) return;

    logInfo('Navigating to online screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const OnlineScreen()),
    );
  }
}
