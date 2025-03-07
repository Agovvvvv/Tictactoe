import 'package:flutter/material.dart';
import 'package:vanishingtictactoe/models/utils/logger.dart';

/// Represents the different ranks in the game
enum Rank {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  master,
  grandmaster
}

/// Represents divisions within a rank
enum Division {
  iv,
  iii,
  ii,
  i
}

/// Class that handles the ranking system logic
class RankSystem {
  // Rank points thresholds for each rank
  static const Map<Rank, int> _rankThresholds = {
    Rank.bronze: 0,
    Rank.silver: 400,
    Rank.gold: 800,
    Rank.platinum: 1200,
    Rank.diamond: 1600,
    Rank.master: 2000,
    Rank.grandmaster: 2400,
  };
  
  // Points needed to advance to the next division
  static const int pointsPerDivision = 100;
  
  // Initial values for new players
  static const int initialMmr = 800;  // Hidden matchmaking rating
  static const int initialRankPoints = 0;  // Visible rank points
  
  /// Get the next rank after the current rank
  static Rank? getNextRank(Rank currentRank) {
    final ranks = Rank.values;
    final currentIndex = ranks.indexOf(currentRank);
    
    if (currentIndex < ranks.length - 1) {
      return ranks[currentIndex + 1];
    }
    
    return null; // Already at the highest rank
  }
  
  /// Get the points required for a specific division within a rank
  static int getPointsForDivision(Rank rank, int division) {
    final basePoints = _rankThresholds[rank] ?? 0;
    
    // Convert division number (1-4) to points required
    // Division 4 (IV) requires 0 points above base rank points
    // Division 3 (III) requires 100 points above base rank points
    // Division 2 (II) requires 200 points above base rank points
    // Division 1 (I) requires 300 points above base rank points
    return basePoints + ((4 - division) * pointsPerDivision);
  }
  
  /// Get the points required for the next division
  static int getPointsForNextDivision(Rank rank, int division) {
    // If already at division 1, get points for next rank's division 4
    if (division == 1) {
      final nextRank = getNextRank(rank);
      if (nextRank != null) {
        return _rankThresholds[nextRank] ?? (_rankThresholds[rank]! + 400);
      }
      // If already at highest rank and division, just add 100 points as a goal
      return getPointsForDivision(rank, division) + pointsPerDivision;
    }
    
    // Get points needed for the next division up
    // Example: If in Bronze 4 (division=4), we need points for Bronze 3 (division=3)
    return getPointsForDivision(rank, division - 1);
  }
  
  /// Get the rank based on rank points
  static Rank getRankFromPoints(int rankPoints) {
    Rank currentRank = Rank.bronze;
    
    for (final entry in _rankThresholds.entries) {
      if (rankPoints >= entry.value) {
        currentRank = entry.key;
      } else {
        break;
      }
    }
    
    return currentRank;
  }
  
  /// Get the division within the current rank
  static Division getDivisionFromPoints(int rankPoints, Rank rank) {
    // Get the base points for this rank
    final basePoints = _rankThresholds[rank] ?? 0;
    
    // Calculate points within this rank
    final pointsInRank = rankPoints - basePoints;
    
    
    // Determine division based on points within rank
    Division division;
    
    if (pointsInRank >= 300) {
      division = Division.i;  // 300+ points = Division I
    } else if (pointsInRank >= 200) {
      division = Division.ii; // 200-299 points = Division II
    } else if (pointsInRank >= 100) {
      division = Division.iii; // 100-199 points = Division III
    } else {
      division = Division.iv; // 0-99 points = Division IV
    }
    
    
    return division;
  }
  
  /// Get the points required for the next rank
  static int? getNextRankThreshold(Rank currentRank) {
    final ranks = Rank.values;
    final currentIndex = ranks.indexOf(currentRank);
    
    if (currentIndex < ranks.length - 1) {
      final nextRank = ranks[currentIndex + 1];
      return _rankThresholds[nextRank];
    }
    
    return null; // Already at the highest rank
  }
  
  /// Get the points required for the next division
  static int? getNextDivisionThreshold(int rankPoints, Rank rank, Division division) {
    final basePoints = _rankThresholds[rank] ?? 0;
    
    // If already at Division I, get points for next rank
    if (division == Division.i) {
      final nextRank = getNextRank(rank);
      if (nextRank != null) {
        return _rankThresholds[nextRank];
      }
      // If at highest rank and division, just add 100 points as a goal
      return basePoints + (4 * pointsPerDivision);
    }
    
    // Calculate threshold for next division
    switch (division) {
      case Division.iv:
        return basePoints + 100; // Next is Division III at 100 points
      case Division.iii:
        return basePoints + 200; // Next is Division II at 200 points
      case Division.ii:
        return basePoints + 300; // Next is Division I at 300 points
      default:
        return basePoints + 400; // Should never reach here
    }
  }
  
  /// Get the rank based on MMR (for matchmaking purposes only)
  static Rank getRankFromMmr(int mmr) {
    // This is now only used for matchmaking purposes
    // We use a different scale for MMR than for visible rank points
    if (mmr < 1000) return Rank.bronze;
    if (mmr < 1500) return Rank.silver;
    if (mmr < 2000) return Rank.gold;
    if (mmr < 2500) return Rank.platinum;
    if (mmr < 3000) return Rank.diamond;
    if (mmr < 3500) return Rank.master;
    return Rank.grandmaster;
  }
  
  // MMR change constants (hidden rating)
  static const int _baseWinMmrPoints = 25;
  static const int _baseLossMmrPoints = 20;
  static const int _baseDrawMmrPoints = 5;
  static const int _maxMmrChange = 50;
  
  // Rank points change constants (visible rating)
  static const int _baseWinRankPoints = 20;
  static const int _baseLossRankPoints = 15;
  static const int _baseDrawRankPoints = 5;
  static const int _maxRankPointsChange = 40;
  
  /// Calculate MMR change after a match (hidden rating)
  static int calculateMmrChange({
    required bool isWin,
    required bool isDraw,
    required int playerMmr,
    required int opponentMmr,
    bool isHellMode = false,
  }) {
    logger.i('Calculating mmr change: isWin=$isWin, isDraw=$isDraw, playerMmr=$playerMmr, opponentMmr=$opponentMmr, isHellMode=$isHellMode');
    if (isDraw) {
      return _calculateDrawMmrChange(playerMmr, opponentMmr);
    } else if (isWin) {
      return _calculateWinMmrChange(playerMmr, opponentMmr, isHellMode);
    } else {
      return _calculateLossMmrChange(playerMmr, opponentMmr, isHellMode);
    }
  }
  
  /// Calculate rank points change after a match (visible rating)
  static int calculateRankPointsChange({
    required bool isWin,
    required bool isDraw,
    required int playerMmr,
    required int opponentMmr,
    bool isHellMode = false,
  }) {
    logger.i('Calculating rank points change: isWin=$isWin, isDraw=$isDraw, playerMmr=$playerMmr, opponentMmr=$opponentMmr, isHellMode=$isHellMode');
    if (isDraw) {
      return _calculateDrawRankPointsChange(playerMmr, opponentMmr);
    } else if (isWin) {
      return _calculateWinRankPointsChange(playerMmr, opponentMmr, isHellMode);
    } else {
      return _calculateLossRankPointsChange(playerMmr, opponentMmr, isHellMode);
    }
  }
  
  /// Calculate MMR change for a win (hidden rating)
  static int _calculateWinMmrChange(int playerMmr, int opponentMmr, bool isHellMode) {
    // Base points for winning
    int points = _baseWinMmrPoints;
    
    // Adjust based on MMR difference
    final mmrDifference = opponentMmr - playerMmr;
    final mmrFactor = mmrDifference / 500; // Normalize the difference
    
    // More points for beating higher-ranked players, fewer for beating lower-ranked
    points += (mmrFactor * 10).round();
    
    // Bonus for Hell Mode
    if (isHellMode) {
      points = (points * 1.5).round(); // 50% bonus for Hell Mode
    }
   
    // Ensure within limits
    return points.clamp(5, _maxMmrChange);
  }
  
  /// Calculate MMR change for a loss (hidden rating)
  static int _calculateLossMmrChange(int playerMmr, int opponentMmr, bool isHellMode) {
    // Base points for losing
    int points = -_baseLossMmrPoints;
    
    // Adjust based on MMR difference
    final mmrDifference = playerMmr - opponentMmr;
    final mmrFactor = mmrDifference / 500; // Normalize the difference
    
    // Lose fewer points when losing to higher-ranked players
    points -= (mmrFactor * 8).round();
    
    // Less penalty in Hell Mode (since it's more challenging)
    if (isHellMode) {
      points = (points * 0.8).round(); // 20% reduction in penalty for Hell Mode
    }
    
    // Ensure within limits (negative values)
    return points.clamp(-_maxMmrChange, -5);
  }
  
  /// Calculate MMR change for a draw (hidden rating)
  static int _calculateDrawMmrChange(int playerMmr, int opponentMmr) {
    // Base points for a draw
    int points = _baseDrawMmrPoints;
    
    // Adjust based on MMR difference
    final mmrDifference = opponentMmr - playerMmr;
    final mmrFactor = mmrDifference / 500; // Normalize the difference
    
    // More points for drawing against higher-ranked players
    points += (mmrFactor * 5).round();
    
    // Ensure within reasonable limits
    return points.clamp(-10, 15);
  }
  
  /// Calculate rank points change for a win (visible rating)
  static int _calculateWinRankPointsChange(int playerMmr, int opponentMmr, bool isHellMode) {
    // Base points for winning
    int points = _baseWinRankPoints;
    
    // Adjust based on MMR difference
    final mmrDifference = opponentMmr - playerMmr;
    final mmrFactor = mmrDifference / 500; // Normalize the difference
    
    // More points for beating higher-ranked players, fewer for beating lower-ranked
    points += (mmrFactor * 8).round();
    
    // Bonus for Hell Mode
    if (isHellMode) {
      points = (points * 1.5).round(); // 50% bonus for Hell Mode
    }
    
    // Ensure within limits
    return points.clamp(5, _maxRankPointsChange);
  }
  
  /// Calculate rank points change for a loss (visible rating)
  static int _calculateLossRankPointsChange(int playerMmr, int opponentMmr, bool isHellMode) {
    // Base points for losing
    int points = -_baseLossRankPoints;
    
    // Adjust based on MMR difference
    final mmrDifference = playerMmr - opponentMmr;
    final mmrFactor = mmrDifference / 500; // Normalize the difference
    
    // Lose fewer points when losing to higher-ranked players
    points -= (mmrFactor * 6).round();
    
    // Less penalty in Hell Mode (since it's more challenging)
    if (isHellMode) {
      points = (points * 0.8).round(); // 20% reduction in penalty for Hell Mode
    }
    
    // Ensure within limits (negative values)
    return points.clamp(-_maxRankPointsChange, -5);
  }
  
  /// Calculate rank points change for a draw (visible rating)
  static int _calculateDrawRankPointsChange(int playerMmr, int opponentMmr) {
    // Base points for a draw
    int points = _baseDrawRankPoints;
    
    // Adjust based on MMR difference
    final mmrDifference = opponentMmr - playerMmr;
    final mmrFactor = mmrDifference / 500; // Normalize the difference
    
    // More points for drawing against higher-ranked players
    points += (mmrFactor * 4).round();
    
    // Ensure within reasonable limits
    return points.clamp(-8, 12);
  }
  
  /// Get the display name for a rank
  static String getRankDisplayName(Rank rank) {
    switch (rank) {
      case Rank.bronze:
        return 'Bronze';
      case Rank.silver:
        return 'Silver';
      case Rank.gold:
        return 'Gold';
      case Rank.platinum:
        return 'Platinum';
      case Rank.diamond:
        return 'Diamond';
      case Rank.master:
        return 'Master';
      case Rank.grandmaster:
        return 'Grandmaster';
    }
  }
  
  /// Get the display name for a division
  static String getDivisionDisplayName(Division division) {
    switch (division) {
      case Division.iv:
        return 'IV';
      case Division.iii:
        return 'III';
      case Division.ii:
        return 'II';
      case Division.i:
        return 'I';
    }
  }

  static int getIntDivision(Division division) {
    // Convert division enum to integer value (4 for IV, 3 for III, etc.)
    switch (division) {
      case Division.iv: return 4;
      case Division.iii: return 3;
      case Division.ii: return 2;
      case Division.i: return 1;
    }
  }

  static Division getDivisionInt(int division) {
    // Convert integer value back to division enum
    switch (division) {
      case 4: return Division.iv;
      case 3: return Division.iii;
      case 2: return Division.ii;
      case 1: return Division.i;
    }
    return Division.iv;
  }
  
  /// Get the full rank display (e.g., "Gold III")
  static String getFullRankDisplay(Rank rank, Division division) {
    return '${getRankDisplayName(rank)} ${getDivisionDisplayName(division)}';
  }
  
  /// Get the progress to the next division or rank
  static double getProgressPercentage(int rankPoints, Rank rank, Division division) {
    final basePoints = _rankThresholds[rank] ?? 0;
    
    // Recalculate the division to ensure it's correct
    final correctDivision = getDivisionFromPoints(rankPoints, rank);
    
    // Use the correct division for calculations
    division = correctDivision;
    
    // Calculate current division's threshold
    int currentThreshold;
    switch (division) {
      case Division.iv:
        currentThreshold = basePoints + 0; // Division IV starts at 0 points above base
        break;
      case Division.iii:
        currentThreshold = basePoints + 100; // Division III starts at 100 points above base
        break;
      case Division.ii:
        currentThreshold = basePoints + 200; // Division II starts at 200 points above base
        break;
      case Division.i:
        currentThreshold = basePoints + 300; // Division I starts at 300 points above base
        break;
    }
    
    // Get next threshold
    final nextThreshold = getNextDivisionThreshold(rankPoints, rank, division) ?? 
                          (basePoints + (4 * pointsPerDivision));
    
    // Calculate points within this division
    final pointsInDivision = rankPoints - currentThreshold;
    final divisionTotalPoints = nextThreshold - currentThreshold;
    
    // Calculate progress percentage
    return (pointsInDivision / divisionTotalPoints).clamp(0.0, 1.0);
  }
  
  /// Get points needed for next division or rank
  static int getPointsNeededForNextDivision(int rankPoints, Rank rank, Division division) {
    final nextThreshold = getNextDivisionThreshold(rankPoints, rank, division);
    if (nextThreshold == null) return 0; // Already at max rank
    
    return nextThreshold - rankPoints;
  }
  
  /// Get the color associated with a rank
  static Color getRankColor(Rank rank) {
    switch (rank) {
      case Rank.bronze:
        return Colors.brown.shade400;
      case Rank.silver:
        return Colors.grey.shade400;
      case Rank.gold:
        return Colors.amber.shade400;
      case Rank.platinum:
        return Colors.cyan.shade300;
      case Rank.diamond:
        return Colors.lightBlue.shade300;
      case Rank.master:
        return Colors.purple.shade300;
      case Rank.grandmaster:
        return Colors.red.shade400;
    }
  }
  
  /// Get the icon associated with a rank
  static IconData getRankIcon(Rank rank) {
    switch (rank) {
      case Rank.bronze:
        return Icons.shield_outlined;
      case Rank.silver:
        return Icons.shield;
      case Rank.gold:
        return Icons.workspace_premium;
      case Rank.platinum:
        return Icons.diamond_outlined;
      case Rank.diamond:
        return Icons.diamond;
      case Rank.master:
        return Icons.military_tech;
      case Rank.grandmaster:
        return Icons.emoji_events;
    }
  }

  /// Convert a string rank name to the corresponding Rank enum value
  static Rank getRankFromString(String rankName) {
    final normalizedName = rankName.toLowerCase().trim();
    
    switch (normalizedName) {
      case 'bronze':
        return Rank.bronze;
      case 'silver':
        return Rank.silver;
      case 'gold':
        return Rank.gold;
      case 'platinum':
        return Rank.platinum;
      case 'diamond':
        return Rank.diamond;
      case 'master':
        return Rank.master;
      case 'grandmaster':
        return Rank.grandmaster;
      default:
        return Rank.bronze; // Default to bronze for unknown ranks
    }
  }
}
