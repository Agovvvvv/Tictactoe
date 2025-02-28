import 'dart:async';
import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import 'user_profile_screen.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final FriendService _friendService = FriendService();
  List<Map<String, dynamic>> searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(value);
    });
  }

  Future<void> _searchUsers(String username) async {
    if (username.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await _friendService.searchUsers(username);
      setState(() {
        searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error searching users: ${e.toString()}', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      await _friendService.sendFriendRequest(userId);
      _showSnackBar('Friend request sent successfully');
    } catch (e) {
      _showSnackBar('Error sending friend request: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Friend', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          _buildSearchField(),
          if (_isLoading)
            _buildLoadingIndicator()
          else if (_usernameController.text.isEmpty)
            _buildInitialMessage()
          else if (searchResults.isEmpty)
            _buildNoResultsFound()
          else
            _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _usernameController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          labelText: 'Search by username',
          hintText: 'Search by username...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildInitialMessage() {
    return const Expanded(
      child: Center(
        child: Text(
          'Enter a username to search for friends',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No users found matching "${_usernameController.text}"',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: ListView.builder(
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final user = searchResults[index];
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(user['username'] ?? 'Unknown'),
            trailing: TextButton(
              onPressed: () => _sendFriendRequest(user['id']),
              child: const Text('Add'),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    user: user,
                    isFriend: false,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}