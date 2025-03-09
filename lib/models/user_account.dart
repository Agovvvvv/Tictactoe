import 'user_level.dart';

class GameStats {
  int gamesPlayed;
  int gamesWon;
  int gamesLost;
  int gamesDraw;
  DateTime? lastPlayed;
  int highestWinStreak;
  int currentWinStreak;
  int totalMovesToWin;
  int winningGames;

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

  double get winRate => gamesPlayed == 0 ? 0 : gamesWon / gamesPlayed * 100;
  double get averageMovesToWin => winningGames == 0 ? 0 : totalMovesToWin / winningGames;

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
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      gamesWon: json['gamesWon'] as int? ?? 0,
      gamesLost: json['gamesLost'] as int? ?? 0,
      gamesDraw: json['gamesDraw'] as int? ?? 0,
      lastPlayed: json['lastPlayed'] != null ? DateTime.tryParse(json['lastPlayed'] as String) : null,
      highestWinStreak: json['highestWinStreak'] as int? ?? 0,
      currentWinStreak: json['currentWinStreak'] as int? ?? 0,
      totalMovesToWin: json['totalMovesToWin'] as int? ?? 0,
      winningGames: json['winningGames'] as int? ?? 0,
    );
  }

  void updateStats({bool? isWin, bool? isDraw, int? movesToWin}) {
    gamesPlayed++;
    lastPlayed = DateTime.now();

    if (isWin == true) {
      gamesWon++;
      currentWinStreak++;
      if (currentWinStreak > highestWinStreak) highestWinStreak = currentWinStreak;
      if (movesToWin != null) {
        totalMovesToWin += movesToWin;
        winningGames++;
      }
    } else if (isWin == false) {
      gamesLost++;
      currentWinStreak = 0;
    } else if (isDraw == true) {
      gamesDraw++;
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


  UserAccount({
    required this.id,
    required this.username,
    required this.email,
    GameStats? vsComputerStats,
    GameStats? onlineStats,
    this.isOnline = false,
    this.totalXp = 0,
    UserLevel? userLevel,
  })  : vsComputerStats = vsComputerStats ?? GameStats(),
        onlineStats = onlineStats ?? GameStats(),
        userLevel = userLevel ?? UserLevel.fromTotalXp(totalXp);

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
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final userLevelData = json['userLevel'];
    final storedTotalXp = json['totalXp'] as int? ?? 0;
    final userLevel = userLevelData != null ? UserLevel.fromJson(userLevelData as Map<String, dynamic>) : UserLevel.fromTotalXp(storedTotalXp);


    return UserAccount(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      vsComputerStats: json['vsComputerStats'] != null ? GameStats.fromJson(json['vsComputerStats'] as Map<String, dynamic>) : null,
      onlineStats: json['onlineStats'] != null ? GameStats.fromJson(json['onlineStats'] as Map<String, dynamic>) : null,
      isOnline: json['isOnline'] as bool? ?? false,
      totalXp: storedTotalXp,
      userLevel: userLevel,
    );
  }

  void updateStats({bool? isWin, bool? isDraw, int? movesToWin, required bool isOnline}) {
    if (isOnline) {
      onlineStats.updateStats(isWin: isWin, isDraw: isDraw, movesToWin: movesToWin);
    } else {
      vsComputerStats.updateStats(isWin: isWin, isDraw: isDraw, movesToWin: movesToWin);
    }
  }

  UserAccount copyWith({
    String? id,
    String? username,
    String? email,
    GameStats? vsComputerStats,
    GameStats? onlineStats,
    bool? isOnline,
    int? totalXp,
    UserLevel? userLevel,
  }) {
    final newTotalXp = totalXp ?? this.totalXp;
    final newUserLevel = userLevel ?? (totalXp != null ? UserLevel.fromTotalXp(newTotalXp) : this.userLevel);

    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      vsComputerStats: vsComputerStats ?? this.vsComputerStats,
      onlineStats: onlineStats ?? this.onlineStats,
      isOnline: isOnline ?? this.isOnline,
      totalXp: newTotalXp,
      userLevel: newUserLevel,
    );
  }

  UserAccount addXp(int xpToAdd) {
    if (xpToAdd <= 0) return this;
    final newTotalXp = totalXp + xpToAdd;
    final newUserLevel = UserLevel.fromTotalXp(newTotalXp);
    return copyWith(totalXp: newTotalXp, userLevel: newUserLevel);
  }

}