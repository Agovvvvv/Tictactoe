import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/matchmaking_service.dart';
import '../../models/match.dart';
import '../game_screen.dart';
import '../../models/player.dart';
import '../../logic/game_logic_online.dart';

class MatchFoundScreen extends StatefulWidget {
  final String matchId;
  
  const MatchFoundScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<MatchFoundScreen> createState() => _MatchFoundScreenState();
}

class _MatchFoundScreenState extends State<MatchFoundScreen> with TickerProviderStateMixin {
  final MatchmakingService _matchmakingService = MatchmakingService();
  GameMatch? _match;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Animation controllers
  late AnimationController _flipController;
  late AnimationController _scaleController;
  
  // Animations
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  
  // Animation state
  bool _showCoinFlip = false;
  bool _coinFlipComplete = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize flip animation
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _flipAnimation = Tween<double>(
      begin: 0,
      end: math.pi * 6, // 3 full rotations
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeOutBack,
    ));
    
    // Initialize scale animation
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));
    
    // Load match data
    _loadMatch();
  }
  
  @override
  void dispose() {
    _flipController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
  
  Future<void> _loadMatch() async {
    try {
      // Subscribe to match updates
      _matchmakingService.joinMatch(widget.matchId).listen(
        (match) {
          setState(() {
            _match = match;
            _isLoading = false;
            
            // Show coin flip animation after a short delay
            if (!_showCoinFlip) {
              _startCoinFlipSequence();
            }
          });
        },
        onError: (error) {
          setState(() {
            _isLoading = false;
            _errorMessage = error.toString();
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  void _startCoinFlipSequence() {
    // Start showing the coin with scale animation
    setState(() {
      _showCoinFlip = true;
    });
    
    _scaleController.forward().then((_) {
      // Short pause before flipping
      Timer(const Duration(milliseconds: 500), () {
        // Start the flip animation
        _flipController.forward().then((_) {
          // Mark coin flip as complete
          setState(() {
            _coinFlipComplete = true;
          });
          
          // Navigate to game after a short delay
          Timer(const Duration(seconds: 2), () {
            if (mounted && _match != null) {
              _navigateToGame();
            }
          });
        });
      });
    });
  }
  
  void _navigateToGame() {
    if (_match == null) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.id;
    
    if (userId == null) {
      setState(() {
        _errorMessage = 'You must be logged in to play online';
      });
      return;
    }
    
    // Create game logic for online play
    final gameLogic = GameLogicOnline(
      onGameEnd: (_) {},  // Will be handled by GameScreen
      onPlayerChanged: () {},  // Will be handled by GameScreen
      localPlayerId: userId,
      gameId: widget.matchId, // Ensure both players join the same game instance
    );
    
    // Determine local player and opponent
    final isPlayer1 = _match!.player1.id == userId;
    final localPlayer = isPlayer1 ? _match!.player1 : _match!.player2;
    final opponent = isPlayer1 ? _match!.player2 : _match!.player1;
    
    // Navigate to game screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          player1: Player(
            name: localPlayer.name,
            symbol: localPlayer.symbol,
          ),
          player2: Player(
            name: opponent.name,
            symbol: opponent.symbol,
          ),
          logic: gameLogic,
          isOnlineGame: true,
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
        title: const Text(
          'Match Found',
          style: TextStyle(color: Colors.black),
        ),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildMatchFoundContent(),
    );
  }
  
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[700],
            ),
            const SizedBox(height: 20),
            Text(
              'Error Loading Match',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage?.replaceAll('Exception: ', '') ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMatchFoundContent() {
    if (_match == null) return const SizedBox.shrink();
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.id;
    
    // Determine if current user is player1 or player2
    final isPlayer1 = _match!.player1.id == userId;
    final opponent = isPlayer1 ? _match!.player2 : _match!.player1;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Opponent info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Playing Against',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  opponent.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 60),
          
          // Coin flip animation
          if (_showCoinFlip)
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  const Text(
                    'Flipping coin to decide who goes first...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      // Show the appropriate side of the coin based on animation value
                      final showFront = _coinFlipComplete 
                          ? _match!.currentTurn == 'X' 
                          : (_flipAnimation.value / math.pi).floor() % 2 == 0;
                      
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // Perspective
                          ..rotateY(_flipAnimation.value),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: showFront ? Colors.blue : Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              showFront ? 'X' : 'O',
                              style: const TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          
          // Result text after coin flip
          if (_coinFlipComplete)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Text(
                _match!.currentTurn == 'X' ? 'X goes first!' : 'O goes first!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          
          // Starting game message
          if (_coinFlipComplete)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Starting game...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
