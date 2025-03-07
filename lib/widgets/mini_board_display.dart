import 'package:flutter/material.dart';

class MiniBoardDisplay extends StatefulWidget {
  final List<String> board;
  final int highlightedCell;

  const MiniBoardDisplay({
    super.key,
    required this.board,
    required this.highlightedCell,
  });

  @override
  State<MiniBoardDisplay> createState() => _MiniBoardDisplayState();
}

class _MiniBoardDisplayState extends State<MiniBoardDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: List.generate(9, (index) {
          final value = widget.board[index];
          final isHighlighted = index == widget.highlightedCell;
          
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: isHighlighted
                  ? AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _opacityAnimation.value,
                          child: Text(
                            widget.board[widget.highlightedCell].isEmpty ? '?' : widget.board[widget.highlightedCell],
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    )
                  : value.isEmpty
                      ? const SizedBox()
                      : Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
            ),
          );
        }),
      ),
    );
  }
}
