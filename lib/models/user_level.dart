import '../logic/computer_player.dart';

class UserLevel {
  final int level;
  final int currentXp;
  final int xpToNextLevel;

  UserLevel({
    required this.level,
    required this.currentXp,
    required this.xpToNextLevel,
  });

  // Calculate the XP required for a specific level
  static int xpRequiredForLevel(int level) {
    // Formula: Base XP (100) * level * (1 + level/10)
    // This creates a curve where higher levels require more XP
    return (100 * level * (1 + level / 10)).round();
  }

  // Calculate total XP required to reach a specific level from level 1
  static int totalXpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += xpRequiredForLevel(i);
    }
    return total;
  }

  // Calculate level and XP from total XP
  static UserLevel fromTotalXp(int totalXp) {
    if (totalXp <= 0) {
      return UserLevel(level: 1, currentXp: 0, xpToNextLevel: xpRequiredForLevel(1));
    }

    int level = 1;
    int xpRequired = xpRequiredForLevel(level);
    int accumulatedXp = 0;

    while (accumulatedXp + xpRequired <= totalXp) {
      accumulatedXp += xpRequired;
      level++;
      xpRequired = xpRequiredForLevel(level);
    }

    int currentXp = totalXp - accumulatedXp;
    return UserLevel(
      level: level,
      currentXp: currentXp,
      xpToNextLevel: xpRequired,
    );
  }

  // Calculate total XP accumulated including current level's XP
  int get totalXp {
    int previousLevelsXp = totalXpForLevel(level);
    return previousLevelsXp + currentXp;
  }

  // Calculate progress percentage to next level (0 to 100)
  double get progressPercentage {
    if (xpToNextLevel <= 0) return 0.0; // Prevent division by zero
    double percentage = (currentXp / xpToNextLevel) * 100;
    if (percentage.isNaN || percentage.isInfinite) return 0.0; // Handle edge cases
    return percentage;
  }

  // Calculate XP for game results
  static int calculateGameXp({
    required bool isWin,
    required bool isDraw,
    int? movesToWin,
    required int level,
    bool isHellMode = false,
    GameDifficulty difficulty = GameDifficulty.easy,
  }) {
    // Base XP values based on difficulty - EXACT values as specified
    int xpToAward;
    
    if (isWin) {
      // Winning XP values
      switch (difficulty) {
        case GameDifficulty.easy:
          xpToAward = 20;
          break;
        case GameDifficulty.medium:
          xpToAward = 40;
          break;
        case GameDifficulty.hard:
          xpToAward = 60;
          break;
      }
    } else if (isDraw) {
      // Drawing XP values
      switch (difficulty) {
        case GameDifficulty.easy:
          xpToAward = 10;
          break;
        case GameDifficulty.medium:
          xpToAward = 20;
          break;
        case GameDifficulty.hard:
          xpToAward = 30;
          break;
      }
    } else {
      // Losing XP values
      switch (difficulty) {
        case GameDifficulty.easy:
          xpToAward = 5;
          break;
        case GameDifficulty.medium:
          xpToAward = 10;
          break;
        case GameDifficulty.hard:
          xpToAward = 15;
          break;
      }
    }
    
    // Hell mode bonus (double XP)
    if (isHellMode) {
      xpToAward *= 2;
    }
    
    return xpToAward;
  }
  

  // Create a copy with updated values
  UserLevel copyWith({
    int? level,
    int? currentXp,
    int? xpToNextLevel,
  }) {
    return UserLevel(
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'currentXp': currentXp,
      'xpToNextLevel': xpToNextLevel,
    };
  }

  // Create from JSON data
  factory UserLevel.fromJson(Map<String, dynamic> json) {
    return UserLevel(
      level: json['level'] ?? 1,
      currentXp: json['currentXp'] ?? 0,
      xpToNextLevel: json['xpToNextLevel'] ?? 100,
    );
  }
}
