import 'package:cloud_firestore/cloud_firestore.dart';

enum MissionType {
  daily,
  weekly,
}

enum MissionCategory {
  normal,
  hell,
}

class Mission {
  final String id;
  final String title;
  final String description;
  final int xpReward;
  final MissionType type;
  final MissionCategory category;
  final int targetCount;
  final int currentCount;
  final bool completed;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String missionKey; // Unique identifier for the mission type

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.type,
    required this.category,
    required this.targetCount,
    required this.currentCount,
    required this.completed,
    required this.createdAt,
    required this.expiresAt,
    required this.missionKey,
  });

  double get progressPercentage {
    if (targetCount <= 0) return 0.0;
    double percentage = (currentCount / targetCount) * 100;
    if (percentage.isNaN || percentage.isInfinite) return 0.0;
    return percentage > 100 ? 100.0 : percentage;
  }

  bool get isExpired {
    final now = DateTime.now();
    return now.isAfter(expiresAt);
  }

  Mission copyWith({
    String? id,
    String? title,
    String? description,
    int? xpReward,
    MissionType? type,
    MissionCategory? category,
    int? targetCount,
    int? currentCount,
    bool? completed,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? missionKey,
  }) {
    return Mission(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      xpReward: xpReward ?? this.xpReward,
      type: type ?? this.type,
      category: category ?? this.category,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      missionKey: missionKey ?? this.missionKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'xpReward': xpReward,
      'type': type.toString().split('.').last,
      'category': category.toString().split('.').last,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'missionKey': missionKey,
    };
  }

  factory Mission.fromJson(Map<String, dynamic> json, String documentId) {
    return Mission(
      id: documentId,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      xpReward: json['xpReward'] ?? 0,
      type: _parseMissionType(json['type']),
      category: _parseMissionCategory(json['category']),
      targetCount: json['targetCount'] ?? 0,
      currentCount: json['currentCount'] ?? 0,
      completed: json['completed'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 1)),
      missionKey: json['missionKey'] ?? '',
    );
  }

  static MissionType _parseMissionType(String? type) {
    if (type == 'weekly') return MissionType.weekly;
    return MissionType.daily;
  }

  static MissionCategory _parseMissionCategory(String? category) {
    if (category == 'hell') return MissionCategory.hell;
    return MissionCategory.normal;
  }
}
