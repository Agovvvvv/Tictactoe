import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'game/mode_selection_screen.dart';
import 'friends/friends_screen.dart';
import '../services/friends/friend_service.dart';
import '../models/utils/logger.dart';
import '../providers/user_provider.dart';
import '../providers/mission_provider.dart';
import '../widgets/level_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FriendService _friendService = FriendService();
  StreamSubscription? _requestsSubscription;
  int _friendRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _requestsSubscription = _friendService.getFriendRequests().listen((requests) {
      if (mounted) {
        setState(() {
          _friendRequestCount = requests.length;
        });
      }
    }, onError: (error) {
      // Handle error
      logger.e('Error fetching friend requests: $error');
    });
    
    // Initialize mission provider if user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final missionProvider = Provider.of<MissionProvider>(context, listen: false);
      
      if (userProvider.isLoggedIn) {
        missionProvider.initialize(userProvider.user?.id);
      }
    });
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FriendRequestBadge(
          friendRequestCount: _friendRequestCount,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendsScreen()),
            );
          },
        ),
        actions: const [
          AppBarActions(),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Vanishing\nTic Tac Toe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModeSelectionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Play',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendRequestBadge extends StatelessWidget {
  final int friendRequestCount;
  final VoidCallback onPressed;

  const FriendRequestBadge({
    super.key,
    required this.friendRequestCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          padding: const EdgeInsets.only(top: 15, left: 15),
          icon: const Icon(
            Icons.people,
            color: Colors.black,
            size: 30,
          ),
          onPressed: onPressed,
        ),
        if (friendRequestCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: friendRequestCount > 9
                  ? const Text(
                      '9+',
                      style: TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      '$friendRequestCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
      ],
    );
  }
}

class AppBarActions extends StatelessWidget {
  const AppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    
    return Row(
      children: [
        // Only show level badge if user is logged in and has level data
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LevelBadge.fromUserLevel(
              userLevel: user.userLevel,
              fontSize: 12,
              iconSize: 16,
            ),
          ),
        IconButton(
          icon: const Icon(
            Icons.account_circle,
            color: Colors.black,
            size: 30,
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/account');
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}