import 'package:flutter/material.dart';

class WaitingAnimation extends StatefulWidget {
  final String message;
  
  const WaitingAnimation({
    super.key,
    required this.message,
  });

  @override
  State<WaitingAnimation> createState() => _WaitingAnimationState();
}

class _WaitingAnimationState extends State<WaitingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated loading indicator
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3 * _animation.value),
                    blurRadius: 20 * _animation.value,
                    spreadRadius: 5 * _animation.value,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.sports_esports,
                  size: 50 + (10 * _animation.value),
                  color: Colors.blue,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        // Message with animated dots
        _AnimatedDots(message: widget.message),
      ],
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  final String message;
  
  const _AnimatedDots({
    required this.message,
  });

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    
    _controller.addListener(() {
      if (_controller.status == AnimationStatus.completed) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
        _controller.reset();
        _controller.forward();
      }
    });
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    String dots = '';
    for (int i = 0; i < _dotCount; i++) {
      dots += '.';
    }
    
    return Text(
      '${widget.message}$dots',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }
}
