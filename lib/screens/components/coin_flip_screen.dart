import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../game_screen.dart';
import '../../logic/game_logic_2players.dart';

class CoinFlipScreen extends StatefulWidget {
  final Player player1;
  final Player player2;
  final Function(Player firstPlayer)? onResult;

  const CoinFlipScreen({
    super.key,
    required this.player1,
    required this.player2,
    this.onResult,
  });

  @override
  State<CoinFlipScreen> createState() => _CoinFlipScreenState();
}

class _CoinFlipScreenState extends State<CoinFlipScreen> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _scaleController;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  bool _showCoinFlip = false;
  bool _coinFlipComplete = false;
  late bool _player1GoesFirst;

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

    // Randomly decide who goes first
    _player1GoesFirst = math.Random().nextBool();
    
    // Start the animation sequence
    _startCoinFlipSequence();
  }
  
  @override
  void dispose() {
    _flipController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
  
  void _startCoinFlipSequence() {
    setState(() {
      _showCoinFlip = true;
    });
    
    _scaleController.forward().then((_) {
      Timer(const Duration(milliseconds: 500), () {
        _flipController.forward().then((_) {
          setState(() {
            _coinFlipComplete = true;
          });
          
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _navigateToGame();
            }
          });
        });
      });
    });
  }
  
  void _navigateToGame() {
    // Determine who goes first but keep their original symbols
    final firstPlayer = _player1GoesFirst ? widget.player1 : widget.player2;

    if (widget.onResult != null) {
      widget.onResult!(firstPlayer);
    } else {
      final gameLogic = GameLogic(
        onGameEnd: (_) {},  // Will be handled by GameScreen
        onPlayerChanged: () {},  // Will be handled by GameScreen
        player1Symbol: firstPlayer.symbol,
        player2Symbol: _player1GoesFirst ? widget.player2.symbol : widget.player1.symbol,
      );
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameScreen(
            player1: firstPlayer,
            player2: _player1GoesFirst ? widget.player2 : widget.player1,
            logic: gameLogic,
          ),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Starting Game',
          style: TextStyle(color: Colors.black),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${widget.player1.name} vs ${widget.player2.name}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            
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
                        final showFront = _coinFlipComplete 
                            ? _player1GoesFirst
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
            
            if (_coinFlipComplete)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Text(
                  _player1GoesFirst 
                      ? '${widget.player1.name} (X) goes first!'
                      : '${widget.player2.name} (O) goes first!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            
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
      ),
    );
  }
}
