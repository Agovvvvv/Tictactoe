import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/match.dart';
import '../../models/rank_system.dart';
import '../../providers/user_provider.dart';
import 'online_screen.dart';
import '../../models/utils/logger.dart';


class MatchResultsScreen extends StatefulWidget {
  final GameMatch match;
  final bool isRanked;
  final bool isHellMode;
  final int? rankPointsChange;
  final String? previousDivision;
  final String? newDivision;

  const MatchResultsScreen({
    super.key,
    required this.match,
    this.isRanked = false,
    this.isHellMode = false,
    this.rankPointsChange,
    this.previousDivision,
    this.newDivision,
  });

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen> with TickerProviderStateMixin {
  FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _showRankChange = false;

  @override
  void initState() {
    super.initState();
    // Animation for the rank change card
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Animation for the progress bar
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );
    
    // Delay showing rank change animation
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      
      // If rankPointsChange is provided directly, use it
      if (widget.rankPointsChange != null) {
        setState(() {
          _showRankChange = true;
          _animationController.forward();
          _progressController.forward();
        });
        return;
      }
      
      // Otherwise, try to fetch from Firestore
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (!userProvider.isLoggedIn) return;
      
      final userId = userProvider.user?.id;
      if (userId == null) return;
      
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (!mounted) return;
        
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          final lastRankPointsChange = data['lastRankPointsChange'] as int?;
          
          if (lastRankPointsChange != null) {
            setState(() {
              _showRankChange = true;
              _animationController.forward();
              _progressController.forward();
            });
          }
        }
      } catch (e) {
        logger.e('Error fetching rank points change: $e');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
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
            widget.isRanked ? 'Ranked Match Results' : 'Match Results',
            style: TextStyle(
              color: widget.isHellMode ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: widget.isHellMode ? Colors.red.shade900 : Colors.white,
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
                if (widget.isRanked) ...[  
                  _buildRankChangeInfo(),
                  const SizedBox(height: 20),
                  _buildRankProgressBar(),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 20),
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
      resultColor = Colors.amber;
      resultIcon = Icons.balance;
    } else if (isWinner) {
      resultText = "Victory!";
      resultColor = Colors.green;
      resultIcon = Icons.emoji_events;
    } else {
      resultText = "Defeat";
      resultColor = Colors.red;
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
                border: Border.all(color: Colors.red.shade800),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.whatshot, color: Colors.red.shade800, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'HELL MODE',
                    style: TextStyle(
                      color: Colors.red.shade900,
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
      width: 120,
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

  Widget _buildRankChangeInfo() {
    if (!_showRankChange) {
      return const SizedBox(height: 100);
    }
    
    final rankPointsChange = widget.rankPointsChange!;
    final isPositive = rankPointsChange > 0;
    final isNeutral = rankPointsChange == 0;
    
    Color changeColor = isPositive 
        ? Colors.green 
        : (isNeutral ? Colors.grey : Colors.red);
    
    String changeText = isPositive 
        ? '+$rankPointsChange' 
        : (isNeutral ? '$rankPointsChange' : '$rankPointsChange');
    
    bool hasDivisionChanged = widget.previousDivision != widget.newDivision && 
                             widget.previousDivision != null && 
                             widget.newDivision != null;
    
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(_animation),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              const Text(
                'Rank Update',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Rank Points: ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    changeText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: changeColor,
                    ),
                  ),
                  Icon(
                    isPositive 
                        ? Icons.arrow_upward 
                        : (isNeutral ? Icons.remove : Icons.arrow_downward),
                    color: changeColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildRankProgressBar(),
              const SizedBox(height: 10),
              if (hasDivisionChanged) ...[
                const SizedBox(height: 20),
                const Text(
                  'Division Change!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDivisionBadge(widget.previousDivision!),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    _buildDivisionBadge(widget.newDivision!, isNew: true),
                  ],
                ),
              ] else if (widget.newDivision != null) ...[
                const SizedBox(height: 16),
                _buildDivisionBadge(widget.newDivision!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionBadge(String division, {bool isNew = false}) {
    final rankParts = division.split(' ');
    final rankName = rankParts.isNotEmpty ? rankParts.first : 'BRONZE';
    final rankColor = RankSystem.getRankColor(RankSystem.getRankFromString(rankName));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: rankColor.withAlpha((0.2 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rankColor,
          width: isNew ? 2 : 1,
        ),
        boxShadow: isNew ? [
          BoxShadow(
            color: rankColor.withAlpha((0.5 * 255).toInt()),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ] : null,
      ),
      child: Text(
        division,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: rankColor,
        ),
      ),
    );
  }
  
  Widget _buildRankProgressBar() {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    // If user data is missing, return an empty widget
    if (user == null) {
      logger.w('User is null in rank progress bar');
      return const SizedBox.shrink();
    }

    // Get current rank information
    final currentRank = user.rank;
    final currentDivision = RankSystem.getDivisionFromPoints(user.rankPoints, user.rank);
    final rankPoints = user.rankPoints;

    // Calculate points before the change
    final rankPointsChange = widget.rankPointsChange ?? userProvider.user?.lastRankPointsChange ?? 0;
    final previousPoints = rankPoints - rankPointsChange;

    // Log the current user rank data
    logger.i('Building rank progress bar with user data: Previous Points: $previousPoints, New Points: $rankPoints, Change: $rankPointsChange');

    // Calculate previous division based on previous points
    final previousDivision = RankSystem.getDivisionFromPoints(previousPoints, currentRank);

    // Calculate progress for both previous and current points
    final previousProgressPercentage = RankSystem.getProgressPercentage(
      previousPoints,
      currentRank,
      previousDivision
    );

    final currentProgressPercentage = RankSystem.getProgressPercentage(
      rankPoints,
      currentRank,
      currentDivision
    );

    // Animate between previous and current progress
    final progressPercentage = Tween<double>(
      begin: previousProgressPercentage,
      end: currentProgressPercentage,
    ).evaluate(_progressAnimation);

    // Get current threshold and next threshold for points display
    final currentThreshold = RankSystem.getPointsForDivision(currentRank, RankSystem.getIntDivision(currentDivision));
    final nextThreshold = RankSystem.getNextDivisionThreshold(rankPoints, currentRank, currentDivision);
    final pointsInDivision = rankPoints - currentThreshold;
    final previousPointsInDivision = previousPoints - currentThreshold;
    final divisionTotalPoints = (nextThreshold ?? (currentThreshold + 100)) - currentThreshold;

  // Get rank colors
  final currentRankColor = RankSystem.getRankColor(currentRank);

  // Get next division or rank
  String nextDivisionText = '';
  if (RankSystem.getIntDivision(currentDivision) > 1) {
    // Next division in the same rank
    final nextDivision = RankSystem.getDivisionInt(RankSystem.getIntDivision(currentDivision) - 1);
    nextDivisionText = RankSystem.getFullRankDisplay(currentRank, nextDivision);
  } else {
    // If division is 1, next is the next rank
    final nextRank = RankSystem.getNextRank(currentRank);
    if (nextRank != null) {
      nextDivisionText = RankSystem.getFullRankDisplay(nextRank, Division.iv);
    } else {
      // If there's no next rank (e.g., already at top rank)
      nextDivisionText = RankSystem.getFullRankDisplay(currentRank, Division.i);
    }
  }

  // Log progress information for debugging
  logger.i('Building rank progress bar: Previous: $previousPoints ($previousProgressPercentage), Current: $rankPoints ($currentProgressPercentage), Animated: $progressPercentage');

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade200,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(RankSystem.getRankIcon(currentRank), size: 18, color: currentRankColor),
                const SizedBox(width: 6),
                Text(
                  '${user.rank} ${user.division}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: currentRankColor,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  nextDivisionText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            // Background
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Progress
            FractionallySizedBox(
              widthFactor: progressPercentage,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: currentRankColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: currentRankColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Division Progress: $pointsInDivision/$divisionTotalPoints points',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            if (widget.rankPointsChange != null) ...[
              const SizedBox(height: 4),
              Text(
                'Previous: $previousPointsInDivision points',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                widget.rankPointsChange! > 0 ? '+${widget.rankPointsChange} points gained' : '${widget.rankPointsChange} points lost',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.rankPointsChange! > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
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
        label: const Text('Back to Lobby'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _navigateToOnlineScreen() async {
    try {
      // First refresh user data to ensure we have the latest rank information
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      logger.i('Refreshing user data before navigating to online screen');
      
      // Completely reset the user data from Firestore
      await userProvider.refreshUserData(forceServerRefresh: true);
      
      // Log the current user data after refresh
      final user = userProvider.user;
      if (user != null) {
        logger.i('User data after refresh: Rank: ${user.rank}, Division: ${user.division}, Points: ${user.rankPoints}');
      } else {
        logger.w('User is null after refresh');
      }
      
      // Add a small delay to ensure the UI has time to update with the new data
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Create a new instance of OnlineScreen to ensure it's completely rebuilt
      logger.i('Navigating to online screen with ranked tab selected');
      
      // Use pushReplacement instead of pushAndRemoveUntil to maintain the navigation stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnlineScreen(initialMatchType: OnlineMatchType.ranked)),
      );
    } catch (e) {
      logger.e('Error during navigation: $e');
      // Navigate anyway even if there was an error refreshing data
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnlineScreen(initialMatchType: OnlineMatchType.ranked)),
        );
      }
    }
  }
}
