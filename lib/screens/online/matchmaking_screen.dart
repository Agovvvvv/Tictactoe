import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/matchmaking_service.dart';
import 'waiting_animation.dart';
import 'match_found_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  bool _isSearching = true;
  String? _matchId;
  String? _errorMessage;
  final MatchmakingService _matchmakingService = MatchmakingService();
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to ensure the context is available
    Future.microtask(() => _startMatchmaking());
  }

  @override
  void dispose() {
    // If we found a match but are leaving the screen, clean up
    _cancelMatchmaking();
    super.dispose();
  }

  Future<void> _cancelMatchmaking() async {
    if (_isCancelling) return;
    
    setState(() {
      _isCancelling = true;
    });
    
    try {
      // First cancel any active matchmaking
      await _matchmakingService.cancelMatchmaking();
      
      // Then leave the match if we have one
      if (_matchId != null) {
        await _matchmakingService.leaveMatch(_matchId!);
      }
    } catch (e) {
      print('Error cancelling matchmaking: $e');
    }
  }

  Future<void> _startMatchmaking() async {
    // Get the user provider safely
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (userProvider.user == null) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'You must be logged in to play online';
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isSearching = true;
          _errorMessage = null;
        });
      }

      final matchId = await _matchmakingService.findMatch();
      
      if (mounted && !_isCancelling) {
        setState(() {
          _isSearching = false;
          _matchId = matchId;
        });
        
        // Navigate to match found screen with coin flip
        if (mounted && !_isCancelling) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MatchFoundScreen(matchId: matchId),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && !_isCancelling) {
        setState(() {
          _isSearching = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _cancelMatchmaking();
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
              await _cancelMatchmaking();
              if (mounted) {
                mounted ? Navigator.pop(context): null;
              }
            },
          ),
          title: const Text(
            'Online Match',
            style: TextStyle(color: Colors.black),
          ),
        ),
        body: Center(
          child: _isSearching
              ? _buildSearchingWidget()
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildSearchingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const WaitingAnimation(
          message: 'Looking for an opponent',
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () async {
            await _cancelMatchmaking();
            if (mounted) {
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[400],
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
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
            'Error Finding Match',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startMatchmaking,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
