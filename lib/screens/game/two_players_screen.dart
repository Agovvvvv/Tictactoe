import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/player.dart';
import '../components/player_setup_modal.dart';
import '../components/coin_flip_screen.dart';
import '../../services/history/local_match_history_service.dart';
import '../../services/history/match_history_updates.dart';
import '../../models/utils/logger.dart';
import '../../providers/hell_mode_provider.dart';
import 'Hell/hell_game_screen.dart';

class TwoPlayersHistoryScreen extends StatefulWidget {
  const TwoPlayersHistoryScreen({super.key});

  @override
  State<TwoPlayersHistoryScreen> createState() => _TwoPlayersHistoryScreenState();
}

class _TwoPlayersHistoryScreenState extends State<TwoPlayersHistoryScreen> with WidgetsBindingObserver {
  final LocalMatchHistoryService _matchHistoryService = LocalMatchHistoryService();
  List<Map<String, dynamic>> recentMatches = [];
  List<Map<String, dynamic>> hellMatches = [];
  StreamSubscription? _updateSubscription;
  bool _showHellMatches = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for updates
    _updateSubscription = MatchHistoryUpdates.updates.stream.listen((_) {
      logger.i('Received update notification, refreshing matches...');
      _loadRecentMatches();
    });
    _loadRecentMatches();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecentMatches();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecentMatches();
  }

  Future<void> _loadRecentMatches() async {
  if (!mounted) return; // Ensure the widget is still mounted before proceeding

  final matches = await _matchHistoryService.getRecentMatches();
  if (mounted) {
    setState(() {
      // Separate regular matches from hell mode matches
      recentMatches = matches.where((match) => match['is_hell_mode'] != true).toList();
      hellMatches = matches.where((match) => match['is_hell_mode'] == true).toList();
    });
  }
}

  void _startNewGame() async {
    final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
    final isHellModeActive = hellModeProvider.isHellModeActive;
    
    final List<Player>? players = await showDialog(
      context: context,
      builder: (context) => const PlayerSetupModal(),
    );
    
    if (players != null && context.mounted) {
      if (isHellModeActive) {
        // If hell mode is active, go to hell game screen
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HellGameScreen(
              player1: players[0],
              player2: players[1],
            ),
          ),
        );
        
        // If we have a result from the hell game, save it
        if (result != null && result is Map<String, dynamic>) {
          await _saveHellModeMatch(result);
        }
      } else {
        // Normal flow - go to coin flip screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CoinFlipScreen(
              player1: players[0],
              player2: players[1],
            ),
          ),
        );
      }
      
      // Refresh match history when returning from the game
      _loadRecentMatches();
    }
  }
  
  // Save a hell mode match to history
  Future<void> _saveHellModeMatch(Map<String, dynamic> result) async {
    await _matchHistoryService.saveMatch(
      player1: result['player1'],
      player2: result['player2'],
      winner: result['winner'],
      player1WentFirst: result['player1WentFirst'],
      player1Symbol: result['player1Symbol'],
      player2Symbol: result['player2Symbol'],
      isHellMode: true,
    );
    
    // Notify listeners that match history has been updated
    MatchHistoryUpdates.notifyUpdate();
  }

  void _rematch(Map<String, dynamic> match) async {
    if (context.mounted) {
      final isHellMode = match['is_hell_mode'] == true;
      final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
      
      // Ensure hell mode is active if needed
      if (isHellMode && !hellModeProvider.isHellModeActive) {
        hellModeProvider.toggleHellMode();
      } else if (!isHellMode && hellModeProvider.isHellModeActive) {
        hellModeProvider.toggleHellMode();
      }
      
      if (isHellMode) {
        // Rematch in hell mode
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HellGameScreen(
              player1: Player(name: match['player1'], symbol: match['player1_symbol'] ?? 'X'),
              player2: Player(name: match['player2'], symbol: match['player2_symbol'] ?? 'O'),
            ),
          ),
        );
        
        // If we have a result from the hell game, save it
        if (result != null && result is Map<String, dynamic>) {
          await _saveHellModeMatch(result);
        }
      } else {
        // Regular rematch
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CoinFlipScreen(
              player1: Player(name: match['player1'], symbol: match['player1_symbol'] ?? 'X'),
              player2: Player(name: match['player2'], symbol: match['player2_symbol'] ?? 'O'),
            ),
          ),
        );
      }
      
      // Refresh match history when returning from the game
      _loadRecentMatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        await _loadRecentMatches();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            await _loadRecentMatches();
            if (context.mounted) Navigator.pop(context);
          },
        ),
        title: const Text(
          '2 Players',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          // Toggle between regular and hell mode matches
          Consumer<HellModeProvider>(builder: (context, hellModeProvider, child) {
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Regular matches tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showHellMatches = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_showHellMatches ? Colors.blue : Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          'REGULAR MATCHES',
                          style: TextStyle(
                            color: !_showHellMatches ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  // Hell matches tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showHellMatches = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _showHellMatches ? Colors.red.shade900 : Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_showHellMatches)
                              const Icon(
                                Icons.whatshot,
                                size: 16,
                                color: Colors.yellow,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              'HELL MATCHES',
                              style: TextStyle(
                                color: _showHellMatches ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          
          Expanded(
            child: _showHellMatches
                ? (hellMatches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hell mode matches yet',
                              style: GoogleFonts.pressStart2p(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Play a game to see your history',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: hellMatches.length,
                        itemBuilder: (context, index) {
                          final match = hellMatches[index];
                          final player1 = match['player1'] as String;
                          final player2 = match['player2'] as String;
                          final winner = match['winner'] as String;
                          final timestamp = DateTime.parse(match['timestamp'] as String);
                          final formattedDate = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
                          
                          String resultText;
                          Color resultColor;
                          
                          if (winner == 'draw') {
                            resultText = 'Draw';
                            resultColor = Colors.orange;
                          } else {
                            final winnerName = winner == 'X' ? player1 : player2;
                            resultText = '$winnerName wins';
                            resultColor = winner == 'X' ? Colors.blue : Colors.red;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.grey.shade900,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: Colors.red.shade800,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.whatshot,
                                            size: 16,
                                            color: Colors.yellow,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'HELL MODE',
                                            style: GoogleFonts.pressStart2p(
                                              fontSize: 10,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$player1 (X)',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'vs',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '$player2 (O)',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: resultColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      resultText,
                                      style: TextStyle(
                                        color: resultColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _rematch(match),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.red.shade800,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: const Text('REMATCH'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ))
                : (recentMatches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matches yet',
                              style: GoogleFonts.pressStart2p(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Play a game to see your history',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: recentMatches.length,
                        itemBuilder: (context, index) {
                          final match = recentMatches[index];
                          final player1 = match['player1'] as String;
                          final player2 = match['player2'] as String;
                          final winner = match['winner'] as String;
                          final timestamp = DateTime.parse(match['timestamp'] as String);
                          final formattedDate = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
                          
                          String resultText;
                          Color resultColor;
                          
                          if (winner == 'draw') {
                            resultText = 'Draw';
                            resultColor = Colors.orange;
                          } else {
                            final winnerName = winner == 'X' ? player1 : player2;
                            resultText = '$winnerName wins';
                            resultColor = winner == 'X' ? Colors.blue : Colors.red;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: Colors.blue.shade300,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'REGULAR MATCH',
                                        style: GoogleFonts.pressStart2p(
                                          fontSize: 10,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$player1 (X)',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'vs',
                                        style: TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '$player2 (O)',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: resultColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      resultText,
                                      style: TextStyle(
                                        color: resultColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _rematch(match),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: const Text('REMATCH'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
          ),
          Consumer<HellModeProvider>(
            builder: (context, hellModeProvider, child) {
              final isHellModeActive = hellModeProvider.isHellModeActive;
              
              return Column(
                children: [
                  // Hell mode indicator and toggle button
                  if (isHellModeActive)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () => hellModeProvider.toggleHellMode(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.whatshot,
                                size: 20,
                                color: Colors.yellow,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'DEACTIVATE HELL MODE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Play button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startNewGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isHellModeActive ? Colors.red : Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isHellModeActive ? 'PLAY HELL MODE' : 'Play',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isHellModeActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ));
  }
}
