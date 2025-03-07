import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mission_provider.dart';
import '../providers/hell_mode_provider.dart';
import '../screens/missions/missions_screen.dart';
import '../../models/mission.dart';

class MissionIcon extends StatefulWidget {
  const MissionIcon({super.key});

  @override
  State<MissionIcon> createState() => _MissionIconState();
}

class _MissionIconState extends State<MissionIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missionProvider = Provider.of<MissionProvider>(context);
    final hellModeProvider = Provider.of<HellModeProvider>(context);
    final isHellMode = hellModeProvider.isHellModeActive;
    
    // Count completed missions that haven't been claimed
    final completedMissions = missionProvider.missions
        .where((mission) => mission.completed)
        .toList();
    
    // Filter by hell mode if active
    final filteredMissions = isHellMode
        ? completedMissions.where((m) => m.category == MissionCategory.hell).toList()
        : completedMissions.where((m) => m.category == MissionCategory.normal).toList();
    
    final hasCompletedMissions = filteredMissions.isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MissionsScreen()),
        );
      },
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: hasCompletedMissions ? _rotationAnimation.value * 3.14 : 0,
                child: Transform.scale(
                  scale: hasCompletedMissions ? _scaleAnimation.value : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isHellMode ? Colors.red.shade800 : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
          if (hasCompletedMissions)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    filteredMissions.length > 9 ? '9+' : '${filteredMissions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
