import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for tracking chapter reading progress
class ChapterProgress {
  final int chapterId;
  final int versesRead;
  final int totalVerses;
  final DateTime lastReadAt;
  final bool isCompleted;

  ChapterProgress({
    required this.chapterId,
    required this.versesRead,
    required this.totalVerses,
    required this.lastReadAt,
    required this.isCompleted,
  });

  double get progressPercentage =>
      totalVerses > 0 ? (versesRead / totalVerses) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'versesRead': versesRead,
    'totalVerses': totalVerses,
    'lastReadAt': lastReadAt.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory ChapterProgress.fromJson(Map<String, dynamic> json) =>
      ChapterProgress(
        chapterId: json['chapterId'] as int,
        versesRead: json['versesRead'] as int,
        totalVerses: json['totalVerses'] as int,
        lastReadAt: DateTime.parse(json['lastReadAt'] as String),
        isCompleted: json['isCompleted'] as bool,
      );
}

/// Provider for tracking reading progress
class ProgressProvider extends ChangeNotifier {
  static const String _storageKey = 'reading_progress';

  Map<int, ChapterProgress> _progressMap = {};

  Map<int, ChapterProgress> get progressMap => _progressMap;

  /// Get overall progress percentage (based on completed chapters out of 114)
  double get overallProgress {
    if (_progressMap.isEmpty) return 0;

    // Calculate based on completed chapters out of 114
    final completedCount = completedChaptersCount;
    return (completedCount / 114) * 100;
  }

  /// Get reading progress percentage (verses read vs total verses)
  double get readingProgress {
    if (_progressMap.isEmpty) return 0;

    int totalVerses = 0;
    int versesRead = 0;

    for (var progress in _progressMap.values) {
      totalVerses += progress.totalVerses;
      versesRead += progress.versesRead;
    }

    return totalVerses > 0 ? (versesRead / totalVerses) * 100 : 0;
  }

  /// Get completed chapters count
  int get completedChaptersCount {
    return _progressMap.values.where((p) => p.isCompleted).length;
  }

  /// Get total chapters with progress
  int get startedChaptersCount {
    return _progressMap.length;
  }

  ProgressProvider() {
    _loadProgress();
  }

  /// Load progress from storage
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? progressJson = prefs.getString(_storageKey);

      if (progressJson != null) {
        final Map<String, dynamic> decoded = json.decode(progressJson);
        _progressMap = decoded.map(
          (key, value) =>
              MapEntry(int.parse(key), ChapterProgress.fromJson(value)),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
  }

  /// Save progress to storage
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> encoded = _progressMap.map(
        (key, value) => MapEntry(key.toString(), value.toJson()),
      );
      await prefs.setString(_storageKey, json.encode(encoded));
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  /// Update progress for a chapter
  Future<void> updateChapterProgress({
    required int chapterId,
    required int versesRead,
    required int totalVerses,
  }) async {
    final isCompleted = versesRead >= totalVerses;

    _progressMap[chapterId] = ChapterProgress(
      chapterId: chapterId,
      versesRead: versesRead,
      totalVerses: totalVerses,
      lastReadAt: DateTime.now(),
      isCompleted: isCompleted,
    );

    await _saveProgress();
    notifyListeners();
  }

  /// Mark a chapter as completed
  Future<void> markChapterCompleted(int chapterId, int totalVerses) async {
    _progressMap[chapterId] = ChapterProgress(
      chapterId: chapterId,
      versesRead: totalVerses,
      totalVerses: totalVerses,
      lastReadAt: DateTime.now(),
      isCompleted: true,
    );

    await _saveProgress();
    notifyListeners();
  }

  /// Get progress for a specific chapter
  ChapterProgress? getChapterProgress(int chapterId) {
    return _progressMap[chapterId];
  }

  /// Check if a chapter is completed
  bool isChapterCompleted(int chapterId) {
    return _progressMap[chapterId]?.isCompleted ?? false;
  }

  /// Reset all progress
  Future<void> resetAllProgress() async {
    _progressMap.clear();
    await _saveProgress();
    notifyListeners();
  }
}
