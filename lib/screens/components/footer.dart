import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  final VoidCallback onHomePressed;
  final VoidCallback onGameOverPressed;

  const Footer({
    super.key,
    required this.onHomePressed,
    required this.onGameOverPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.home, size: 32),
            onPressed: onHomePressed,
          ),
          IconButton(
            icon: const Icon(Icons.flag, size: 32),
            onPressed: onGameOverPressed,
          ),
        ],
      ),
    );
  }
}
