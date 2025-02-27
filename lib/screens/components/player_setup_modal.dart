import 'package:flutter/material.dart';
import '../../models/player.dart';

class PlayerSetupModal extends StatefulWidget {
  const PlayerSetupModal({super.key});

  @override
  State<PlayerSetupModal> createState() => _PlayerSetupModalState();
}

class _PlayerSetupModalState extends State<PlayerSetupModal> {
  final _player1Controller = TextEditingController();
  final _player2Controller = TextEditingController();

  @override
  void dispose() {
    _player1Controller.dispose();
    _player2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Player Setup',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _player1Controller,
              decoration: const InputDecoration(
                labelText: 'Player 1 Name',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
            const SizedBox(height: 20),
            TextField(
              controller: _player2Controller,
              decoration: const InputDecoration(
                labelText: 'Player 2 Name',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () {
                    if (_player1Controller.text.isEmpty || _player2Controller.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter names for both players'),
                          backgroundColor: Colors.black,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      [
                        Player(name: _player1Controller.text, symbol: 'X'),
                        Player(name: _player2Controller.text, symbol: 'O'),
                      ],
                    );
                  },
                  child: const Text(
                    'Start Game',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
