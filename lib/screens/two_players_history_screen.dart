import 'dart:async';

import 'package:flutter/material.dart';
import '../models/player.dart';
import 'components/player_setup_modal.dart';
import 'components/coin_flip_screen.dart';
import '../services/local_match_history_service.dart';
import '../services/match_history_updates.dart';

class TwoPlayersHistoryScreen extends StatefulWidget {
  const TwoPlayersHistoryScreen({super.key});

  @override
  State<TwoPlayersHistoryScreen> createState() => _TwoPlayersHistoryScreenState();
}

class _TwoPlayersHistoryScreenState extends State<TwoPlayersHistoryScreen> with WidgetsBindingObserver {
  final LocalMatchHistoryService _matchHistoryService = LocalMatchHistoryService();
  List<Map<String, dynamic>> recentMatches = [];
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for updates
    _updateSubscription = MatchHistoryUpdates.updates.stream.listen((_) {
      print('Received update notification, refreshing matches...');
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
    final matches = await _matchHistoryService.getRecentMatches();
    setState(() {
      recentMatches = matches;
    });
  }

  void _startNewGame() async {
    final List<Player>? players = await showDialog(
      context: context,
      builder: (context) => const PlayerSetupModal(),
    );
    
    if (players != null && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CoinFlipScreen(
            player1: players[0],
            player2: players[1],
          ),
        ),
      );
      
      // Refresh match history when returning from the game
      _loadRecentMatches();
    }
  }

  void _rematch(Map<String, dynamic> match) async {
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CoinFlipScreen(
            player1: Player(name: match['player1'], symbol: match['player1_symbol'] ?? 'X'),
            player2: Player(name: match['player2'], symbol: match['player2_symbol'] ?? 'O'),
          ),
        ),
      );
      
      // Refresh match history when returning from the game
      _loadRecentMatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _loadRecentMatches();
        return true;
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
          Expanded(
            child: recentMatches.isEmpty
                ? const Center(
                    child: Text(
                      'No recent matches',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: recentMatches.length,
                    itemBuilder: (context, index) {
                      final match = recentMatches[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            '${match['player1']} vs ${match['player2']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Winner: ${match['winner']}',
                          ),
                          trailing: TextButton(
                            onPressed: () => _rematch(match),
                            child: const Text('Rematch'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startNewGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Play',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
