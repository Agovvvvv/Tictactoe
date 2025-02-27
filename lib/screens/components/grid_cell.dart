import 'package:flutter/material.dart';

class GridCell extends StatefulWidget {
  final String value;
  final int index;
  final bool isVanishing;
  final VoidCallback onTap;

  const GridCell({
    super.key,
    required this.value,
    required this.index,
    required this.isVanishing,
    required this.onTap,
  });

  @override
  State<GridCell> createState() => _GridCellState();
}

class _GridCellState extends State<GridCell> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500), // Flash speed
      vsync: this,
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
    if (widget.isVanishing) {
      _controller.repeat(reverse: true); // Flash on/off
    }
  }

  @override
  void didUpdateWidget(GridCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setState(() {}); // Ensure rebuild when value changes
    }
    if (widget.isVanishing != oldWidget.isVanishing) {
      if (widget.isVanishing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0; // Reset to fully opaque
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: widget.isVanishing ? _opacity.value : 1.0,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
