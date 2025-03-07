import 'user_level.dart';
import 'rank_system.dart';

class GameStats {
  int gamesPlayed;
  int gamesWon;
  int gamesLost;
  int gamesDraw;
  DateTime? lastPlayed;
  int highestWinStreak;
  int currentWinStreak;
  int totalMovesToWin; // Total moves taken in winning games
  int winningGames; // Number of games where moves were counted

  GameStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.gamesDraw = 0,
    this.lastPlayed,
    this.highestWinStreak = 0,
    this.currentWinStreak = 0,
    this.totalMovesToWin = 0,
    this.winningGames = 0,
  });

  double get winRate {
    if (gamesPlayed == 0) return 0;
    return gamesWon / gamesPlayed * 100;
  }

  double get averageMovesToWin {
    if (winningGames == 0) return 0;
    return totalMovesToWin / winningGames;
  }

  Map<String, dynamic> toJson() {
    return {
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'gamesLost': gamesLost,
      'gamesDraw': gamesDraw,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'highestWinStreak': highestWinStreak,
      'currentWinStreak': currentWinStreak,
      'totalMovesToWin': totalMovesToWin,
      'winningGames': winningGames,
    };
  }

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      gamesPlayed: json['gamesPlayed'] ?? 0,
      gamesWon: json['gamesWon'] ?? 0,
      gamesLost: json['gamesLost'] ?? 0,
      gamesDraw: json['gamesDraw'] ?? 0,
      lastPlayed: json['lastPlayed'] != null ? DateTime.parse(json['lastPlayed']) : null,
      highestWinStreak: json['highestWinStreak'] ?? 0,
      currentWinStreak: json['currentWinStreak'] ?? 0,
      totalMovesToWin: json['totalMovesToWin'] ?? 0,
      winningGames: json['winningGames'] ?? 0,
    );
  }

  void updateStats({bool? isWin, bool? isDraw, int? movesToWin}) {
    gamesPlayed++;
    lastPlayed = DateTime.now();

    if (isWin == true) {
      gamesWon++;
      currentWinStreak++;
      if (currentWinStreak > highestWinStreak) {
        highestWinStreak = currentWinStreak;
      }
      if (movesToWin != null) {
        totalMovesToWin += movesToWin;
        winningGames++;
      }
    } else if (isWin == false) {
      gamesLost++;
      currentWinStreak = 0;
    } else if (isDraw == true) {
      gamesDraw++;
      // Draw doesn't break the win streak
    }
  }
}


class UserAccount {
  final String id;
  final String username;
  final String email;
  final GameStats vsComputerStats;
  final GameStats onlineStats;
  final bool isOnline;
  final int totalXp;
  final UserLevel userLevel;
  final int mmr;          // Hidden matchmaking rating
  final int rankPoints;   // Visible rank points
  final Rank rank;
  final Division division;
  final int? lastRankPointsChange;  // Tracks the last change in rank points after a match
  final String? previousDivision;   // Stores the previous division before a rank change
  
  // Getters for rank information
  String get rankName => rank.toString().split('.').last.toUpperCase();
  String get divisionName => division.toString().split('.').last.toUpperCase();
  String get fullRank => '$rankName $divisionName';

  UserAccount({
    required this.id,
    required this.username,
    required this.email,
    GameStats? vsComputerStats,
    GameStats? onlineStats,
    this.isOnline = false,
    this.totalXp = 0,
    UserLevel? userLevel,
    int? mmr,
    int? rankPoints,
    Rank? rank,
    Division? division,
    this.lastRankPointsChange,
    this.previousDivision,
  }) : vsComputerStats = vsComputerStats ?? GameStats(),
       onlineStats = onlineStats ?? GameStats(),
       userLevel = userLevel ?? UserLevel.fromTotalXp(totalXp),
       mmr = mmr ?? RankSystem.initialMmr,
       rankPoints = rankPoints ?? RankSystem.initialRankPoints,
       rank = rank ?? (rankPoints != null ? RankSystem.getRankFromPoints(rankPoints) : RankSystem.getRankFromMmr(mmr ?? RankSystem.initialMmr)),
       division = division ?? (rankPoints != null ? RankSystem.getDivisionFromPoints(rankPoints, rank ?? RankSystem.getRankFromPoints(rankPoints)) : Division.iv);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'vsComputerStats': vsComputerStats.toJson(),
      'onlineStats': onlineStats.toJson(),
      'isOnline': isOnline,
      'lastOnline': DateTime.now().toIso8601String(),
      'totalXp': totalXp,
      'userLevel': userLevel.toJson(),
      'mmr': mmr,
      'rankPoints': rankPoints,
      'rank': rank.toString().split('.').last,
      'division': division.toString().split('.').last,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    // First try to get the user level data if it exists
    final userLevelData = json['userLevel'];
    final storedTotalXp = json['totalXp'] ?? 0;
    UserLevel userLevel;
    
    if (userLevelData != null) {
      // If we have user level data, use it and calculate total XP from it
      userLevel = UserLevel.fromJson(userLevelData);
    } else {
      // If no user level data, create from total XP
      userLevel = UserLevel.fromTotalXp(storedTotalXp);
    }
    
    // Get MMR or use default
    final mmr = json['mmr'] ?? RankSystem.initialMmr;
    
    // Get rank points or use default
    final rankPoints = json['rankPoints'] ?? RankSystem.initialRankPoints;
    
    // Get rank from string or calculate from rank points
    Rank rank;
    if (json['rank'] != null) {
      try {
        rank = Rank.values.firstWhere(
          (r) => r.toString().split('.').last == json['rank'],
          orElse: () => RankSystem.getRankFromPoints(rankPoints),
        );
      } catch (_) {
        rank = RankSystem.getRankFromPoints(rankPoints);
      }
    } else {
      rank = RankSystem.getRankFromPoints(rankPoints);
    }
    
    // Always calculate division from rank points to ensure accuracy
    // Ignoring stored division value to prevent display issues
    final division = RankSystem.getDivisionFromPoints(rankPoints, rank);
    
    // Log if there's a mismatch between stored and calculated division
    if (json['division'] != null) {
      try {
        final storedDivision = Division.values.firstWhere(
          (d) => d.toString().split('.').last == json['division'],
          orElse: () => division,
        );
        
        if (storedDivision != division) {
          print('DEBUG: Division mismatch - Stored: $storedDivision, Calculated: $division for $rankPoints points');
        }
      } catch (_) {
        // Ignore parsing errors
      }
    }
    
    return UserAccount(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      vsComputerStats: json['vsComputerStats'] != null 
          ? GameStats.fromJson(json['vsComputerStats'])
          : null,
      onlineStats: json['onlineStats'] != null 
          ? GameStats.fromJson(json['onlineStats'])
          : null,
      isOnline: json['isOnline'] ?? false,
      totalXp: userLevel.totalXp, // Always use the XP calculated from user level
      userLevel: userLevel,
      mmr: mmr,
      rankPoints: rankPoints,
      rank: rank,
      division: division,
    );
  }

  void updateStats({bool? isWin, bool? isDraw, int? movesToWin, required bool isOnline}) {
    if (isOnline) {
      onlineStats.updateStats(isWin: isWin, isDraw: isDraw, movesToWin: movesToWin);
    } else {
      vsComputerStats.updateStats(isWin: isWin, isDraw: isDraw, movesToWin: movesToWin);
    }
  }

  // Create a copy of the user account with optional updated fields
  UserAccount copyWith({
    String? id,
    String? username,
    String? email,
    GameStats? vsComputerStats,
    GameStats? onlineStats,
    bool? isOnline,
    int? totalXp,
    UserLevel? userLevel,
    int? mmr,
    int? rankPoints,
    Rank? rank,
    Division? division,
  }) {
    final newTotalXp = totalXp ?? this.totalXp;
    final newUserLevel = userLevel ?? (totalXp != null ? UserLevel.fromTotalXp(newTotalXp) : this.userLevel);
    final newMmr = mmr ?? this.mmr;
    final newRankPoints = rankPoints ?? this.rankPoints;
    final newRank = rank ?? (rankPoints != null ? RankSystem.getRankFromPoints(newRankPoints) : this.rank);
    final newDivision = division ?? (rankPoints != null ? RankSystem.getDivisionFromPoints(newRankPoints, newRank) : this.division);
    
    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      vsComputerStats: vsComputerStats ?? this.vsComputerStats,
      onlineStats: onlineStats ?? this.onlineStats,
      isOnline: isOnline ?? this.isOnline,
      totalXp: newTotalXp,
      userLevel: newUserLevel,
      mmr: newMmr,
      rankPoints: newRankPoints,
      rank: newRank,
      division: newDivision,
    );
  }
  
  // Add XP to the user account and return a new instance with updated XP and level
  UserAccount addXp(int xpToAdd) {
    if (xpToAdd <= 0) return this;
    
    final newTotalXp = totalXp + xpToAdd;
    final newUserLevel = UserLevel.fromTotalXp(newTotalXp);
    
    return copyWith(
      totalXp: newTotalXp,
      userLevel: newUserLevel,
    );
  }
  
  // Update MMR and rank points after a ranked match
  UserAccount updateRank(int mmrChange, int rankPointsChange) {
    if (mmrChange == 0 && rankPointsChange == 0) return this;
    
    // Calculate new MMR, ensuring it doesn't go below 0
    final newMmr = (mmr + mmrChange).clamp(0, 10000);
    
    // Calculate new rank points, ensuring it doesn't go below 0
    final newRankPoints = (rankPoints + rankPointsChange).clamp(0, 10000);
    
    // Calculate new rank and division based on rank points
    final newRank = RankSystem.getRankFromPoints(newRankPoints);
    final newDivision = RankSystem.getDivisionFromPoints(newRankPoints, newRank);
    
    return copyWith(
      mmr: newMmr,
      rankPoints: newRankPoints,
      rank: newRank,
      division: newDivision,
    );
  }
  
  // Legacy method for backward compatibility
  UserAccount updateMmr(int mmrChange) {
    if (mmrChange == 0) return this;
    
    // Calculate new MMR, ensuring it doesn't go below 0
    final newMmr = (mmr + mmrChange).clamp(0, 10000);
    
    // For backward compatibility, also update rank points by the same amount
    final newRankPoints = (rankPoints + mmrChange).clamp(0, 10000);
    
    // Calculate new rank and division based on rank points
    final newRank = RankSystem.getRankFromPoints(newRankPoints);
    final newDivision = RankSystem.getDivisionFromPoints(newRankPoints, newRank);
    
    return copyWith(
      mmr: newMmr,
      rankPoints: newRankPoints,
      rank: newRank,
      division: newDivision,
    );
  }
}
