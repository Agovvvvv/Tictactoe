import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.people,
            color: Colors.black,
            size: 30,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendsScreen()),
            );
          },
        ),
        actions: [
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
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModeSelectionScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                ),
              ),
              child: const Text('Play'),
            ),
            ],
          ),
        ),
      );
    
  }
}
