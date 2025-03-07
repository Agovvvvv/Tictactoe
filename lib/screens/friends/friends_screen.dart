import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/friends/friend_service.dart';
import '../../providers/user_provider.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}


class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> filteredFriends = [];
  List<Map<String, dynamic>> friendRequests = [];
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _requestsSubscription;
  Timer? _refreshTimer;
  ScaffoldMessengerState _scaffoldMessenger = ScaffoldMessengerState();

  @override
  void initState() {
    super.initState();
    _requestsSubscription = _friendService.getFriendRequests().listen((requests) {
      if (mounted) {
        setState(() {
          friendRequests = requests;
        });
      }
    });

    _friendsSubscription = _friendService.getFriends().listen((friendsList) {
      if (mounted) {
        setState(() {
          friends = friendsList;
          _filterFriends(_searchController.text);
        });
      }
    });
    
    // Set up periodic refresh of friends' online status
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshFriendsStatus();
    });
  }

  void _filterFriends(String query) {
    setState(() {
      filteredFriends = friends
          .where((friend) => friend['username'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }
  
  Future<void> _refreshFriendsStatus() async {
    if (friends.isEmpty || !mounted) return;
    
    try {
      final updatedFriends = await _friendService.refreshFriendsStatus(friends);
      if (mounted) {
        setState(() {
          friends = updatedFriends;
          _filterFriends(_searchController.text);
        });
      }
    } catch (e) {
      // Silently handle errors during refresh
      debugPrint('Error refreshing friends status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _scaffoldMessenger = ScaffoldMessenger.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    if (!userProvider.isLoggedIn) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'Friends',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      centerTitle: true, // Center the title for better alignment
    ),
    body: Padding(
      padding: const EdgeInsets.all(24.0), // Add padding for better spacing
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey, // Use a subtle icon color
            ),
            const SizedBox(height: 24), // Add spacing between elements
            Text(
              'Please log in to access friends',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700], // Use a softer text color
                fontWeight: FontWeight.w500, // Medium weight for better readability
              ),
              textAlign: TextAlign.center, // Center-align the text
            ),
            const SizedBox(height: 24), // Add spacing before the button
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Use a primary color for the button
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), // Add padding to the button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Rounded corners for the button
                ),
              ),
              child: const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for better contrast
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.pushNamed(context, '/add-friend');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterFriends,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (friendRequests.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Card(
                margin: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Friend Requests',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: friendRequests.length,
                        itemBuilder: (context, index) {
                          final request = friendRequests[index];
                          return Container(
                            height: 70,
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(request['username'] ?? 'Unknown'),
                            
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () async {
                                    final requestId = request['senderId'] as String?;
                                    if (requestId == null) {
                                      if (mounted) {
                                        _scaffoldMessenger.showSnackBar(
                                          const SnackBar(content: Text('Invalid friend request data')),
                                        );
                                      }
                                      return;
                                    }

                                    try {
                                      await _friendService.acceptFriendRequest(requestId);
                                      if (mounted) {
                                        _scaffoldMessenger.showSnackBar(
                                          const SnackBar(content: Text('Friend request accepted')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        _scaffoldMessenger.showSnackBar(
                                          SnackBar(content: Text('Error accepting request: ${e.toString()}')),
                                        );
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () async {
                                    final requestId = request['senderId'] as String?;
                                    if (requestId == null) {
                                      if (mounted) {
                                        _scaffoldMessenger.showSnackBar(
                                          const SnackBar(content: Text('Invalid friend request data')),
                                        );
                                      }
                                      return;
                                    }

                                    try {
                                      await _friendService.rejectFriendRequest(requestId);
                                      if (mounted) {
                                        _scaffoldMessenger.showSnackBar(
                                          const SnackBar(content: Text('Friend request rejected')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        _scaffoldMessenger.showSnackBar(
                                          SnackBar(content: Text('Error rejecting request: ${e.toString()}')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = filteredFriends[index];
                final bool isOnline = friend['isOnline'] ?? false;
                
                return Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(friend['username'] ?? 'Unknown'),
                    subtitle: isOnline 
                      ? const Text('Online', style: TextStyle(color: Colors.green))
                      : null,
                    onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                            user: friend,
                            isFriend: true,
                          ),
                      ),
                    );
                  },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _friendsSubscription?.cancel();
    _requestsSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
