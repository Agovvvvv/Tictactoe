import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mission.dart';
import '../../providers/mission_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/hell_mode_provider.dart';
import '../../widgets/mission_card.dart';
import '../../widgets/mission_complete_animation.dart';
import '../../models/utils/logger.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Mission? _completedMission;
  bool _showAnimation = false;
  bool _showHellMissions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize mission provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final missionProvider = Provider.of<MissionProvider>(context, listen: false);
      
      if (userProvider.isLoggedIn) {
        missionProvider.initialize(userProvider.user?.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showMissionCompleteAnimation(Mission mission) {
    setState(() {
      _completedMission = mission;
      _showAnimation = true;
    });
  }

  void _hideAnimation() {
    setState(() {
      _showAnimation = false;
      _completedMission = null;
    });
  }

  Future<void> _claimMissionReward(Mission mission) async {
    final missionProvider = Provider.of<MissionProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (!userProvider.isLoggedIn) return;
    
    try {
      // Show animation first
      _showMissionCompleteAnimation(mission);
      
      // Claim the reward
      final xpReward = await missionProvider.completeMission(mission.id);
      
      // Add XP to user
      if (xpReward > 0) {
        await userProvider.addXp(xpReward);
        logger.i('Mission completed: ${mission.title}, XP awarded: $xpReward');
      }
    } catch (e) {
      logger.e('Error claiming mission reward: $e');
      // Hide animation if there was an error
      _hideAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final missionProvider = Provider.of<MissionProvider>(context);
    final hellModeProvider = Provider.of<HellModeProvider>(context);
    final isHellMode = hellModeProvider.isHellModeActive;
    final showHellMissions = _showHellMissions;
    
    if (!userProvider.isLoggedIn) {
      return _buildLoginPrompt();
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: showHellMissions ? Colors.red.shade800 : Colors.blue,
        title: Text(
          'Missions',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Improved Mode toggle switch with animation
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Normal mode (star) button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    decoration: BoxDecoration(
                      color: !showHellMissions ? Colors.white : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                      boxShadow: !showHellMissions
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                        onTap: _showHellMissions ? () => setState(() => _showHellMissions = false) : null,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: showHellMissions ? Colors.white54 : Theme.of(context).primaryColor,
                              fontSize: 20,
                            ),
                            child: Icon(Icons.star,
                            color: showHellMissions ? Colors.white54 : Colors.blue
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Hell mode (fire) button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    decoration: BoxDecoration(
                      color: showHellMissions ? Colors.white : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                      boxShadow: showHellMissions
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                        onTap: !_showHellMissions ? () => setState(() => _showHellMissions = true) : null,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: showHellMissions ? Colors.red.shade800 : Colors.white54,
                              fontSize: 20,
                            ),
                            child: Icon(
                              Icons.whatshot,
                              color: showHellMissions ? Colors.red.shade800 : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // Daily missions tab
              _buildMissionsTab(
                missions: missionProvider.dailyMissions,
                isLoading: missionProvider.isLoading,
                emptyMessage: 'No daily missions available',
                isHellMode: isHellMode,
                showHellMissions: showHellMissions,
              ),
              
              // Weekly missions tab
              _buildMissionsTab(
                missions: missionProvider.weeklyMissions,
                isLoading: missionProvider.isLoading,
                emptyMessage: 'No weekly missions available',
                isHellMode: isHellMode,
                showHellMissions: showHellMissions,
              ),
            ],
          ),
          
          // Mission complete animation overlay
          if (_showAnimation && _completedMission != null)
            MissionCompleteAnimation(
              missionTitle: _completedMission!.title,
              xpReward: _completedMission!.xpReward,
              isHellMode: isHellMode,
              onAnimationComplete: _hideAnimation,
            ),
        ],
      ),
    );
  }

  Widget _buildMissionsTab({
    required List<Mission> missions,
    required bool isLoading,
    required String emptyMessage,
    required bool isHellMode,
    required bool showHellMissions,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (missions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    // Filter missions by category based on hell mode
    final filteredMissions = showHellMissions
        ? missions.where((m) => m.category == MissionCategory.hell).toList()
        : missions.where((m) => m.category == MissionCategory.normal).toList();
    
    if (filteredMissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showHellMissions ? Icons.whatshot : Icons.assignment,
              size: 64,
              color: showHellMissions ? Colors.red.shade300 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              showHellMissions
                  ? 'No Hell Mode missions available'
                  : 'No Normal Mode missions available',
              style: TextStyle(
                fontSize: 18,
                color: showHellMissions ? Colors.red.shade300 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMissions.length,
      itemBuilder: (context, index) {
        final mission = filteredMissions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MissionCard(
            mission: mission,
            onClaim: () => _claimMissionReward(mission),
            showAnimation: false,
          ),
        );
      },
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Missions',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Login to access missions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete missions to earn XP and level up',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}