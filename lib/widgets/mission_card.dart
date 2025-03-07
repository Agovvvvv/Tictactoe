import 'package:flutter/material.dart';
import '../models/mission.dart';

class MissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onClaim;
  final bool showAnimation;

  const MissionCard({
    super.key,
    required this.mission,
    required this.onClaim,
    this.showAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final isHellMode = mission.category == MissionCategory.hell;
    final Color primaryColor = isHellMode ? Colors.red.shade800 : Colors.blue;
    final Color backgroundColor = isHellMode ? Colors.red.shade50 : Colors.blue.shade50;
    final IconData typeIcon = mission.type == MissionType.daily
        ? Icons.today
        : Icons.date_range;
    final IconData categoryIcon = isHellMode
        ? Icons.whatshot
        : Icons.games;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: mission.completed ? Colors.green : primaryColor.withValues(alpha: 0.3),
          width: mission.completed ? 2 : 1,
        ),
      ),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  categoryIcon,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Icon(
                  typeIcon,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mission.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                if (showAnimation && mission.completed)
                  _buildCompletionAnimation(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mission.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _buildProgressBar(primaryColor),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${mission.currentCount}/${mission.targetCount}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${mission.xpReward} XP',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mission.completed)
              _buildClaimButton(primaryColor)
            else
              _buildExpiryInfo(context, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color primaryColor) {
    return Stack(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        FractionallySizedBox(
          widthFactor: mission.progressPercentage / 100,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: mission.completed ? Colors.green : primaryColor,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimButton(Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onClaim,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Claim Reward'),
      ),
    );
  }

  Widget _buildExpiryInfo(BuildContext context, Color primaryColor) {
    final now = DateTime.now();
    final difference = mission.expiresAt.difference(now);
    
    String expiryText;
    if (difference.inDays > 0) {
      expiryText = 'Expires in ${difference.inDays} days';
    } else if (difference.inHours > 0) {
      expiryText = 'Expires in ${difference.inHours} hours';
    } else {
      expiryText = 'Expires in ${difference.inMinutes} minutes';
    }
    
    return Text(
      expiryText,
      style: TextStyle(
        fontSize: 12,
        color: difference.inHours < 12 ? Colors.red : Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildCompletionAnimation() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}
