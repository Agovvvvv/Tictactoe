import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mission.dart';
import '../models/utils/logger.dart';
import '../services/mission/mission_service.dart';
import '../logic/computer_player.dart';

class MissionProvider extends ChangeNotifier {
  final MissionService _missionService = MissionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Mission> _missions = [];
  List<Mission> _dailyMissions = [];
  List<Mission> _weeklyMissions = [];
  List<Mission> _normalMissions = [];
  List<Mission> _hellMissions = [];
  
  bool _isLoading = false;
  String? _userId;
  StreamSubscription? _missionsSubscription;
  
  // Getters
  List<Mission> get missions => _missions;
  List<Mission> get dailyMissions => _dailyMissions;
  List<Mission> get weeklyMissions => _weeklyMissions;
  List<Mission> get normalMissions => _normalMissions;
  List<Mission> get hellMissions => _hellMissions;
  bool get isLoading => _isLoading;
  
  // Initialize the provider with user ID
  Future<void> initialize(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _missions = [];
      _dailyMissions = [];
      _weeklyMissions = [];
      _normalMissions = [];
      _hellMissions = [];
      _cancelSubscriptions();
      notifyListeners();
      return;
    }
    
    if (_userId == userId) return; // Already initialized for this user
    
    _userId = userId;
    _isLoading = true;
    notifyListeners();
    
    try {
      // Generate missions if needed
      await _missionService.generateMissions(userId);
      
      // Subscribe to missions updates
      _cancelSubscriptions();
      _missionsSubscription = _missionService.getUserMissions(userId).listen((missions) {
        _missions = missions;
        _filterMissions();
        _isLoading = false;
        notifyListeners();
      }, onError: (error) {
        logger.e('Error loading missions: $error');
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      logger.e('Error initializing mission provider: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Filter missions into categories
  void _filterMissions() {
    _dailyMissions = _missions.where((m) => m.type == MissionType.daily).toList();
    _weeklyMissions = _missions.where((m) => m.type == MissionType.weekly).toList();
    _normalMissions = _missions.where((m) => m.category == MissionCategory.normal).toList();
    _hellMissions = _missions.where((m) => m.category == MissionCategory.hell).toList();
  }
  
  // Manually load missions
  Future<void> loadMissions() async {
    if (_userId == null) return;
    
    try {
      // Generate missions if needed
      await _missionService.generateMissions(_userId!);
      
      // Get current missions
      final missions = await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('missions')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .get();
      
      _missions = missions.docs
          .map((doc) => Mission.fromJson(doc.data(), doc.id))
          .toList();
      
      _filterMissions();
      notifyListeners();
    } catch (e) {
      logger.e('Error loading missions: $e');
    }
  }
  
  // Track game played for missions
  Future<void> trackGamePlayed({
    required bool isHellMode,
    required bool isWin,
    GameDifficulty? difficulty,
  }) async {
    if (_userId == null) return;
    
    try {
      await _missionService.trackGamePlayed(
        userId: _userId!,
        isHellMode: isHellMode,
        isWin: isWin,
        difficulty: difficulty,
      );
      
      // Manually load missions to refresh UI
      await loadMissions();
      
      logger.i('Game played tracked: isHellMode=$isHellMode, isWin=$isWin');
    } catch (e) {
      logger.e('Error tracking game played: $e');
    }
  }
  
  // Complete a mission and claim reward
  Future<int> completeMission(String missionId) async {
    if (_userId == null) return 0;
    
    final xpReward = await _missionService.completeMission(_userId!, missionId);
    return xpReward;
  }
  
  // Cancel subscriptions
  void _cancelSubscriptions() {
    _missionsSubscription?.cancel();
    _missionsSubscription = null;
  }
  
  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
