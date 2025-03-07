import 'package:flutter/material.dart';
import '../models/user_level.dart';

class LevelProgressBar extends StatelessWidget {
  final UserLevel userLevel;
  final double height;
  final double width;
  final Color backgroundColor;
  final Color progressColor;
  final Color textColor;
  final bool showPercentage;
  final bool showLevel;

  const LevelProgressBar({
    super.key,
    required this.userLevel,
    this.height = 12.0,
    this.width = double.infinity,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.progressColor = Colors.blue,
    this.textColor = Colors.black,
    this.showPercentage = false,
    this.showLevel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLevel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level ${userLevel.level}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  'Level ${userLevel.level + 1}',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(builder: (context, constraints) {
          // Calculate progress percentage with safety checks
          double progressPercent = userLevel.progressPercentage / 100;
          // Ensure it's between 0 and 1
          progressPercent = progressPercent.clamp(0.0, 1.0);
          
          // Calculate the actual progress width based on available width
          double maxWidth = width == double.infinity ? constraints.maxWidth : width;
          double progressWidth = maxWidth * progressPercent;
                    
          return Stack(
            children: [
              // Background
              Container(
                height: height,
                width: maxWidth,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              // Progress
              Container(
                height: height,
                width: progressWidth,
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              // XP Text
              if (showPercentage)
                Positioned.fill(
                  child: Center(
                    child: Text(
                      '${userLevel.progressPercentage.toInt()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: height * 0.7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${userLevel.currentXp} / ${userLevel.xpToNextLevel} XP',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
