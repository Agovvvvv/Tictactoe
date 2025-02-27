import 'package:flutter/material.dart';

class ModeButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const ModeButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.black,
        textStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Text(text),
    );
  }
}
