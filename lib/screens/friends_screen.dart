import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/friend_service.dart';
import '../providers/user_provider.dart';
import 'user_profile_screen.dart';

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
  }

  void _filterFriends(String query) {
    setState(() {
      filteredFriends = friends
          .where((friend) => friend['username'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    _scaffoldMessenger = ScaffoldMessenger.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    if (!userProvider.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Friends', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Please log in to access friends',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Log In'),
              ),
            ],
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
                return Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(friend['username'] ?? 'Unknown'),
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
    super.dispose();
  }
}
