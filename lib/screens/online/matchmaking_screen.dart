import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/matches/matchmaking_service.dart';
import 'waiting_animation.dart';
import 'match_found_screen.dart';
import '../../models/utils/logger.dart';

class MatchmakingScreen extends StatefulWidget {
  final bool isHellMode;

  const MatchmakingScreen({
    super.key,
    this.isHellMode = false,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  bool _isSearching = true;
  String? _matchId;
  String? _errorMessage;
  String _statusMessage = 'Initializing matchmaking...';
  final MatchmakingService _matchmakingService = MatchmakingService();
  bool _isCancelling = false;
  int _searchTimeSeconds = 0;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to ensure the context is available
    Future.microtask(() => _startMatchmaking());
  }

  @override
  void dispose() {
    // If we found a match but are leaving the screen, clean up
    // Use a synchronous flag to prevent setState calls after dispose
    _isCancelling = true;
    _cancelMatchmaking();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelMatchmaking() async {
    if (_isCancelling) return;
    
    // Only call setState if the widget is still mounted
    if (mounted) {
      setState(() {
        _isCancelling = true;
      });
    } else {
      // Just set the flag without setState if we're already disposed
      _isCancelling = true;
    }
    
    try {
      // First cancel any active matchmaking
      await _matchmakingService.cancelMatchmaking();
      
      // Then leave the match if we have one
      if (_matchId != null) {
        await _matchmakingService.leaveMatch(_matchId!);
      }
    } catch (e) {
      logger.e('Error cancelling matchmaking: $e');
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
          _statusMessage = 'Initializing matchmaking...';
          _searchTimeSeconds = 0;
        });
      }
      
      // Start a timer to show search time
      _searchTimer?.cancel();
      _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isSearching && !_isCancelling) {
          setState(() {
            _searchTimeSeconds++;
            
            // Update status message based on search time
            if (_searchTimeSeconds < 10) {
              _statusMessage = 'Looking for opponents...';
            } else if (_searchTimeSeconds < 30) {
              _statusMessage = 'Searching for a suitable match...';
            } else if (_searchTimeSeconds < 60) {
              _statusMessage = 'This is taking longer than usual...';
            } else if (_searchTimeSeconds < 120) {
              _statusMessage = 'Still searching. Please be patient...';
            } else {
              _statusMessage = 'Extended search in progress...';
            }
          });
        }
      });

      // Pass hell mode parameters to the matchmaking service
      final matchId = await _matchmakingService.findMatch(
        isHellMode: widget.isHellMode,
      );
      
      _searchTimer?.cancel();
      
      if (mounted && !_isCancelling) {
        setState(() {
          _isSearching = false;
          _matchId = matchId;
          _statusMessage = 'Match found!';
        });
        
        // Navigate to match found screen with coin flip
        if (mounted && !_isCancelling) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MatchFoundScreen(
                matchId: matchId,
                isHellMode: widget.isHellMode,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _searchTimer?.cancel();
      
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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        await _cancelMatchmaking();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: widget.isHellMode ? Colors.red.shade900 : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: widget.isHellMode ? Colors.white : Colors.black),
            onPressed: () async {
              await _cancelMatchmaking();
              if (mounted && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          title: Text(
            'Normal Match',
            style: TextStyle(color: widget.isHellMode ? Colors.white : Colors.black),
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
    final bool isHellMode = widget.isHellMode;
    final String hellModeText = isHellMode ? 'Hell Mode ' : '';
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WaitingAnimation(
          message: 'Looking for a ${hellModeText}opponent',
          isHellMode: isHellMode,
        ),
        const SizedBox(height: 20),
        Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 16,
            color: isHellMode ? Colors.red.shade800 : Colors.blue.shade800,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Time elapsed: ${_formatSearchTime(_searchTimeSeconds)}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 30),
        if (isHellMode) ...[  
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade800),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.whatshot, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Text(
                  'HELL MODE ACTIVE',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        ElevatedButton(
          onPressed: () async {
            await _cancelMatchmaking();
            if (mounted && context.mounted) {
              Navigator.pop(context, true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isHellMode ? Colors.red.shade800 : Colors.red[400],
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    final bool isHellMode = widget.isHellMode;
    
    // Format error message for better readability
    String formattedError = _errorMessage?.replaceAll('Exception: ', '') ?? 'Unknown error';
    String errorTitle = 'Error Finding Match';
    String errorSuggestion = '';
    
    // Provide more specific error messages and suggestions
    if (formattedError.contains('Matchmaking timeout')) {
      errorTitle = 'No Opponents Found';
      formattedError = 'We couldn\'t find an opponent for you at this time.';
      errorSuggestion = 'Try again later when more players are online.';
    } else if (formattedError.contains('permission-denied')) {
      errorTitle = 'Connection Issue';
      formattedError = 'There was a problem connecting to the game server.';
      errorSuggestion = 'Please check your internet connection and try again.';
    }
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: isHellMode ? Colors.red.shade900 : Colors.red[700],
          ),
          const SizedBox(height: 20),
          Text(
            errorTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formattedError,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          if (errorSuggestion.isNotEmpty) ...[  
            const SizedBox(height: 10),
            Text(
              errorSuggestion,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ],
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
  
  // Helper method to format search time
  String _formatSearchTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    if (minutes == 0) {
      return '${seconds}s';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
}
