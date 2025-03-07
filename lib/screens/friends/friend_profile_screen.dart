import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/friends/friend_service.dart';
import '../../services/user/stats_service.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/level_progress_bar.dart';
import '../../models/user_account.dart';
import '../../models/user_level.dart';
import 'dart:developer' as developer;

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isFriend;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.isFriend = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FriendService _friendService = FriendService();
  final StatsService _statsService = StatsService();
  bool _showOnlineStats = false;
  bool _isLoading = false;
  String? _friendRequestStatus;
  Map<String, GameStats>? _userStats;

  @override
  void initState() {
    super.initState();
    _checkFriendRequestStatus();
    _loadUserStats();
  }

  StreamSubscription? _friendRequestSubscription;

  @override
  void dispose() {
    _friendRequestSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _statsService.getUserStats(widget.user['id']);
      if (mounted) {
        setState(() => _userStats = stats);
      }
    } catch (e) {
      developer.log('Error loading user stats: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user stats: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkFriendRequestStatus() async {
    if (widget.isFriend) return;

    setState(() => _isLoading = true);
    try {
      // Cancel any existing subscription
      await _friendRequestSubscription?.cancel();
      
      // Listen to friend requests stream
      _friendRequestSubscription = _friendService.getFriendRequests().listen(
        (requests) {
          if (!mounted) return;
          
          final request = requests.firstWhere(
            (req) => req['id'] == widget.user['id'],
            orElse: () => const {},
          );
          
          setState(() {
            _friendRequestStatus = request.isNotEmpty ? 'pending' : null;
            _isLoading = false;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to check friend request status: ${error.toString()}')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check friend request status: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleFriendAction() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      if (widget.isFriend) {
        // Remove friend
        await _friendService.deleteFriend(widget.user['id']);
        if (mounted) {
          Navigator.of(context).pop(true); // Pop with refresh flag
        }
      } else if (_friendRequestStatus == 'pending') {
        // Accept friend request
        await _friendService.acceptFriendRequest(widget.user['id']);
        if (mounted) {
          Navigator.of(context).pop(true); // Pop with refresh flag
        }
      } else {
        // Send friend request
        await _friendService.sendFriendRequest(widget.user['id']);
        if (mounted) {
          setState(() => _friendRequestStatus = 'sent');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend request sent successfully')),
          );
        }
      }
    } catch (e) {
      developer.log('Error performing friend action: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to perform friend action: ${e.toString()}')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue,
                            child: Text(
                              (widget.user['username'] as String? ?? '?')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 40, color: Colors.white),
                            ),
                          ),
                          if (widget.user['isOnline'] == true)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.user['username'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      // User Level
                      if (widget.user['userLevel'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Level ${UserLevel.fromJson(widget.user['userLevel']).level}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      if (widget.user['isOnline'] == true)
                        const Text(
                          'Online',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      Text(
                        widget.user['displayName'] ?? '',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Level Progress Bar - only show for own profile
                      if (!widget.isFriend && (widget.user['userLevel'] != null || widget.user['totalXp'] != null))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          child: LevelProgressBar(
                            userLevel: widget.user['userLevel'] != null
                                ? UserLevel.fromJson(widget.user['userLevel'])
                                : UserLevel.fromTotalXp(widget.user['totalXp'] ?? 0),
                            progressColor: Colors.blue.shade600,
                            backgroundColor: Colors.blue.shade100,
                            showLevel: false,
                          ),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                          onPressed: _isLoading ? null : _handleFriendAction,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                            backgroundColor: widget.isFriend ? Colors.red : Colors.blue,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  widget.isFriend
                                      ? 'Remove Friend'
                                      : _friendRequestStatus == 'pending'
                                          ? 'Accept Request'
                                          : _friendRequestStatus == 'sent'
                                              ? 'Request Sent'
                                              : 'Add Friend',
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats Toggle
            Row(
              children: [
                _buildToggleButton(
                  title: 'VS Computer',
                  icon: Icons.computer,
                  isSelected: !_showOnlineStats,
                  onTap: () => setState(() => _showOnlineStats = false),
                ),
                const SizedBox(width: 16),
                _buildToggleButton(
                  title: 'Online',
                  icon: Icons.public,
                  isSelected: _showOnlineStats,
                  onTap: () => setState(() => _showOnlineStats = true),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats Section
            _buildStatsSection(
              context,
              title: _showOnlineStats ? 'Online Stats' : 'VS Computer Stats',
              stats: _userStats != null
                ? (_showOnlineStats ? _userStats!['onlineStats']! : _userStats!['vsComputerStats']!)
                : GameStats(),
              icon: _showOnlineStats ? Icons.public : Icons.computer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withValues(alpha:0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, {
    required String title,
    required GameStats stats,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              title: 'Matches Played',
              value: stats.gamesPlayed.toString(),
              icon: Icons.sports_esports,
            ),
            StatCard(
              title: 'Games Won',
              value: stats.gamesWon.toString(),
              icon: Icons.emoji_events,
            ),
            StatCard(
              title: 'Win Rate',
              value: '${stats.winRate.toStringAsFixed(1)}%',
              icon: Icons.trending_up,
            ),
            StatCard(
              title: 'Win Streak',
              value: stats.currentWinStreak.toString(),
              icon: Icons.whatshot,
            ),
            StatCard(
              title: 'Best Streak',
              value: stats.highestWinStreak.toString(),
              icon: Icons.star,
            ),
            StatCard(
              title: 'Avg Moves to Win',
              value: stats.winningGames > 0
                ? stats.averageMovesToWin.toStringAsFixed(1)
                : '-',
              icon: Icons.route,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          stats.lastPlayed != null
            ? 'Last Played: ${_formatDate(stats.lastPlayed!)}'
            : 'No games played yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}