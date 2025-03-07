import 'package:flutter/material.dart';

class WaitingAnimation extends StatefulWidget {
  final String message;
  final bool isHellMode;
  
  const WaitingAnimation({
    super.key,
    required this.message,
    this.isHellMode = false,
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
    final bool isHellMode = widget.isHellMode;
    final Color primaryColor = isHellMode ? Colors.red : Colors.blue;
    final IconData iconData = isHellMode ? Icons.whatshot : Icons.sports_esports;
    
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
                color: primaryColor.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3 * _animation.value),
                    blurRadius: 20 * _animation.value,
                    spreadRadius: 5 * _animation.value,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: 50 + (10 * _animation.value),
                  color: primaryColor,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        // Message with animated dots
        _AnimatedDots(
          message: widget.message,
          isHellMode: widget.isHellMode,
        ),
      ],
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  final String message;
  final bool isHellMode;
  
  const _AnimatedDots({
    required this.message,
    this.isHellMode = false,
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
    
    final Color textColor = widget.isHellMode ? Colors.red.shade900 : Colors.black87;
    
    return Text(
      '${widget.message}$dots',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    );
  }
}
