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

  UserAccount({
    required this.id,
    required this.username,
    required this.email,
    GameStats? vsComputerStats,
    GameStats? onlineStats,
  }) : vsComputerStats = vsComputerStats ?? GameStats(),
       onlineStats = onlineStats ?? GameStats();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'vsComputerStats': vsComputerStats.toJson(),
      'onlineStats': onlineStats.toJson(),
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
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
  }) {
    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      vsComputerStats: vsComputerStats ?? this.vsComputerStats,
      onlineStats: onlineStats ?? this.onlineStats,
    );
  }
}
