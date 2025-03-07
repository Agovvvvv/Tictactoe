import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vanishingtictactoe/screens/game/mode_selection_screen.dart';
import '../../providers/hell_mode_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/rank_system.dart';
import '../../models/utils/logger.dart';
import 'matchmaking_screen.dart';
import '../../widgets/mission_icon.dart';

enum OnlineMatchType {
  normal,
  ranked,
}

class OnlineScreen extends StatefulWidget {
  final bool returnToModeSelection;
  final OnlineMatchType? initialMatchType;
  
  const OnlineScreen({
    super.key,
    this.returnToModeSelection = false,
    this.initialMatchType,
  });

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late OnlineMatchType _selectedMatchType;
  
  @override
  void initState() {
    super.initState();
    // Set initial match type if provided, otherwise default to normal
    _selectedMatchType = widget.initialMatchType ?? OnlineMatchType.normal;
    
    // Refresh user data to get latest rank points
    _refreshUserData();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when dependencies change (e.g., when returning to this screen)
    _refreshUserData();
  }
  
  @override
  void activate() {
    super.activate();
    // This is called when the screen is popped back to from another screen
    logger.i('OnlineScreen: activate called, refreshing user data');
    _refreshUserData();
  }
  
  Future<void> _refreshUserData() async {
    // Use a microtask to ensure this runs after the current frame
    Future.microtask(() async {
      if (!mounted) return;
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isLoggedIn) {
        logger.i('OnlineScreen: Refreshing user data to get latest rank points');
        
        try {
          // Force a complete refresh of user data from server
          await userProvider.refreshUserData(forceServerRefresh: true);
          
          if (!mounted) return;
          
          // Log the current user data after refresh
          final user = userProvider.user;
          if (user != null) {
            logger.i('OnlineScreen - User data after refresh: Rank: ${user.rank}, Division: ${user.division}, Points: ${user.rankPoints}');
            
            // Force a rebuild to ensure UI reflects the latest data
            setState(() {
              // This empty setState forces a rebuild with the latest data
              logger.i('Forcing UI update in OnlineScreen');
            });
          }
        } catch (e) {
          logger.e('Error refreshing user data in OnlineScreen: $e');
        }
      }
    });
  }

  final List<OnlineMatchType> _matchTypes = [
    OnlineMatchType.normal,
    OnlineMatchType.ranked,
  ];

  String _getMatchTypeName(OnlineMatchType matchType) {
    return switch (matchType) {
      OnlineMatchType.normal => 'Normal',
      OnlineMatchType.ranked => 'Ranked',
    };
  }

  void _startMatchmaking() {
    final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
    final isHellMode = hellModeProvider.isHellModeActive;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchmakingScreen(
          isRanked: _selectedMatchType == OnlineMatchType.ranked,
          isHellMode: isHellMode,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from matchmaking
      logger.i('Returned from matchmaking, refreshing user data');
      _refreshUserData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Navigate back to mode selection by popping to first route
            logger.i('Navigating back to mode selection screen');
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ModeSelectionScreen()));
          },
        ),
        title: const Text(
          'Online Match',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: MissionIcon(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildMatchTypeSelector(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getMatchTypeName(_selectedMatchType),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildMatchTypeDescription(),
                  Consumer<HellModeProvider>(
                    builder: (context, hellModeProvider, child) {
                      if (hellModeProvider.isHellModeActive) {
                        return Column(
                          children: [
                            const SizedBox(height: 30),
                            _buildHellModeIndicator(),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const Spacer(),
                  _buildPlayButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTypeSelector() {
    return Card(
      margin: const EdgeInsets.all(20),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Choose your match type',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: _matchTypes.map((matchType) {
                final isSelected = _selectedMatchType == matchType;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: matchType != _matchTypes.last ? 12 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMatchType = matchType),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getMatchTypeName(matchType),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchTypeDescription() {
    final description = _selectedMatchType == OnlineMatchType.normal
        ? 'Play casual games with other players. Your rating will not be affected.'
        : 'Compete in ranked games to improve your position on the leaderboard.';
    
    final icon = _selectedMatchType == OnlineMatchType.normal
        ? Icons.sports_esports
        : Icons.emoji_events;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: _selectedMatchType == OnlineMatchType.normal ? Colors.blue : Colors.amber.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedMatchType == OnlineMatchType.ranked)
              _buildPlayerRankInfo(),
          ],
        ),
      ),
    );
  }
  
  // Using the RankSystem color method instead

  Widget _buildPlayerRankInfo() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (!userProvider.isLoggedIn) {
          return const SizedBox.shrink();
        }
        
        final user = userProvider.user!;
        
        // Recalculate division based on rank points to ensure accuracy
        final correctDivision = RankSystem.getDivisionFromPoints(user.rankPoints, user.rank);
        print('DEBUG: User has ${user.rankPoints} points, stored division: ${user.division}, calculated division: $correctDivision');
        
        // Use the correct division for display
        final fullRankName = RankSystem.getFullRankDisplay(user.rank, correctDivision);
        final rankColor = RankSystem.getRankColor(user.rank);
        final rankIcon = RankSystem.getRankIcon(user.rank);
        
        // Calculate progress to next division/rank using the correct division
        final progressPercentage = RankSystem.getProgressPercentage(
          user.rankPoints, 
          user.rank, 
          correctDivision
        );
        
        final pointsNeeded = RankSystem.getPointsNeededForNextDivision(
          user.rankPoints, 
          user.rank, 
          correctDivision
        );
        
        final nextThreshold = RankSystem.getNextDivisionThreshold(user.rankPoints, user.rank, correctDivision);
        final isMaxRank = nextThreshold == null;
        
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(rankIcon, color: rankColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    fullRankName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isMaxRank) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rank Points: ${user.rankPoints}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$pointsNeeded points to next tier',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPercentage,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                Text(
                  'Maximum Rank Achieved!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: rankColor,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildHellModeIndicator() {
    return Center(
      child: Container(
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
    );
  }

  Widget _buildPlayButton() {
    return Consumer<HellModeProvider>(
      builder: (context, hellModeProvider, child) {
        final isHellModeActive = hellModeProvider.isHellModeActive;
        final isRanked = _selectedMatchType == OnlineMatchType.ranked;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startMatchmaking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isHellModeActive 
                    ? Colors.red.shade900 
                    : (isRanked ? Colors.amber.shade700 : Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isHellModeActive)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.whatshot, color: Colors.yellow),
                    ),
                  Text(
                    isHellModeActive 
                        ? 'PLAY HELL MODE' 
                        : (isRanked ? 'PLAY RANKED' : 'PLAY CASUAL'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isHellModeActive || isRanked ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}