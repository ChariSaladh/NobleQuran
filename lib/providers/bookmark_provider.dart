import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bookmark folder model
class BookmarkFolder {
  final String id;
  String name;
  final DateTime createdAt;
  String color;
  String icon;

  BookmarkFolder({
    required this.id,
    required this.name,
    DateTime? createdAt,
    this.color = '#1B7958',
    this.icon = 'folder',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'color': color,
    'icon': icon,
  };

  factory BookmarkFolder.fromJson(Map<String, dynamic> json) => BookmarkFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    color: json['color'] as String? ?? '#1B7958',
    icon: json['icon'] as String? ?? 'folder',
  );
}

/// Bookmark model for saved verses
class Bookmark {
  final int chapterId;
  final int verseNumber;
  final String chapterName;
  final DateTime createdAt;
  String? folderId; // null means "All Bookmarks" (no folder)

  Bookmark({
    required this.chapterId,
    required this.verseNumber,
    required this.chapterName,
    DateTime? createdAt,
    this.folderId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'verseNumber': verseNumber,
    'chapterName': chapterName,
    'createdAt': createdAt.toIso8601String(),
    'folderId': folderId,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    chapterId: json['chapterId'] as int,
    verseNumber: json['verseNumber'] as int,
    chapterName: json['chapterName'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    folderId: json['folderId'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark &&
          runtimeType == other.runtimeType &&
          chapterId == other.chapterId &&
          verseNumber == other.verseNumber;

  @override
  int get hashCode => chapterId.hashCode ^ verseNumber.hashCode;
}

/// Provider for managing bookmarks and folders
class BookmarkProvider extends ChangeNotifier {
  List<Bookmark> _bookmarks = [];
  List<BookmarkFolder> _folders = [];
  String? _currentFolderId;

  List<Bookmark> get bookmarks => _bookmarks;
  List<BookmarkFolder> get folders => _folders;
  String? get currentFolderId => _currentFolderId;

  // Get bookmarks for current folder (or all if no folder selected)
  List<Bookmark> get currentFolderBookmarks {
    if (_currentFolderId == null) {
      return _bookmarks;
    }
    return _bookmarks.where((b) => b.folderId == _currentFolderId).toList();
  }

  // Get unfoldered bookmarks (for "All" view)
  List<Bookmark> get unfolderedBookmarks {
    return _bookmarks.where((b) => b.folderId == null).toList();
  }

  static const String _bookmarksStorageKey = 'quran_bookmarks';
  static const String _foldersStorageKey = 'quran_bookmark_folders';

  BookmarkProvider() {
    _loadData();
  }

  /// Load bookmarks and folders from storage
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load folders
      final String? foldersData = prefs.getString(_foldersStorageKey);
      if (foldersData != null) {
        final List<dynamic> foldersJson = json.decode(foldersData);
        _folders = foldersJson
            .map(
              (item) => BookmarkFolder.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }

      // Load bookmarks
      final String? bookmarksData = prefs.getString(_bookmarksStorageKey);
      if (bookmarksData != null) {
        final List<dynamic> bookmarksJson = json.decode(bookmarksData);
        _bookmarks = bookmarksJson
            .map((item) => Bookmark.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  /// Save bookmarks to storage
  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(
        _bookmarks.map((b) => b.toJson()).toList(),
      );
      await prefs.setString(_bookmarksStorageKey, data);
    } catch (e) {
      debugPrint('Error saving bookmarks: $e');
    }
  }

  /// Save folders to storage
  Future<void> _saveFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String data = json.encode(_folders.map((f) => f.toJson()).toList());
      await prefs.setString(_foldersStorageKey, data);
    } catch (e) {
      debugPrint('Error saving folders: $e');
    }
  }

  /// Set current folder
  void setCurrentFolder(String? folderId) {
    _currentFolderId = folderId;
    notifyListeners();
  }

  /// Check if a verse is bookmarked
  bool isBookmarked(int chapterId, int verseNumber) {
    return _bookmarks.any(
      (b) => b.chapterId == chapterId && b.verseNumber == verseNumber,
    );
  }

  /// Add a bookmark (optionally to a folder)
  Future<void> addBookmark({
    required int chapterId,
    required int verseNumber,
    required String chapterName,
    String? folderId,
  }) async {
    // Check if already bookmarked
    if (isBookmarked(chapterId, verseNumber)) return;

    final bookmark = Bookmark(
      chapterId: chapterId,
      verseNumber: verseNumber,
      chapterName: chapterName,
      folderId: folderId ?? _currentFolderId,
    );

    _bookmarks.add(bookmark);
    await _saveBookmarks();
    notifyListeners();
  }

  /// Remove a bookmark
  Future<void> removeBookmark(int chapterId, int verseNumber) async {
    _bookmarks.removeWhere(
      (b) => b.chapterId == chapterId && b.verseNumber == verseNumber,
    );
    await _saveBookmarks();
    notifyListeners();
  }

  /// Move bookmark to a folder
  Future<void> moveBookmarkToFolder(
    int chapterId,
    int verseNumber,
    String? folderId,
  ) async {
    final index = _bookmarks.indexWhere(
      (b) => b.chapterId == chapterId && b.verseNumber == verseNumber,
    );
    if (index != -1) {
      _bookmarks[index].folderId = folderId;
      await _saveBookmarks();
      notifyListeners();
    }
  }

  /// Toggle bookmark
  Future<void> toggleBookmark({
    required int chapterId,
    required int verseNumber,
    required String chapterName,
  }) async {
    if (isBookmarked(chapterId, verseNumber)) {
      await removeBookmark(chapterId, verseNumber);
    } else {
      await addBookmark(
        chapterId: chapterId,
        verseNumber: verseNumber,
        chapterName: chapterName,
      );
    }
  }

  /// Create a new folder
  Future<void> createFolder({
    required String name,
    String color = '#1B7958',
    String icon = 'folder',
  }) async {
    final folder = BookmarkFolder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      color: color,
      icon: icon,
    );

    _folders.add(folder);
    await _saveFolders();
    notifyListeners();
  }

  /// Delete a folder
  Future<void> deleteFolder(String folderId) async {
    // Move all bookmarks in this folder to unfoldered
    for (var bookmark in _bookmarks) {
      if (bookmark.folderId == folderId) {
        bookmark.folderId = null;
      }
    }

    _folders.removeWhere((f) => f.id == folderId);

    await _saveFolders();
    await _saveBookmarks();

    // Reset current folder if deleted
    if (_currentFolderId == folderId) {
      _currentFolderId = null;
    }

    notifyListeners();
  }

  /// Rename a folder
  Future<void> renameFolder(String folderId, String newName) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      _folders[index].name = newName;
      await _saveFolders();
      notifyListeners();
    }
  }

  /// Update folder color
  Future<void> updateFolderColor(String folderId, String color) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      _folders[index].color = color;
      await _saveFolders();
      notifyListeners();
    }
  }

  /// Get folder by ID
  BookmarkFolder? getFolder(String folderId) {
    try {
      return _folders.firstWhere((f) => f.id == folderId);
    } catch (e) {
      return null;
    }
  }

  /// Get bookmark count in a folder
  int getBookmarkCount(String? folderId) {
    if (folderId == null) {
      return _bookmarks.length;
    }
    return _bookmarks.where((b) => b.folderId == folderId).length;
  }

  /// Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    _bookmarks.clear();
    await _saveBookmarks();
    notifyListeners();
  }

  /// Clear all folders
  Future<void> clearAllFolders() async {
    // Reset folderId for all bookmarks
    for (var bookmark in _bookmarks) {
      bookmark.folderId = null;
    }

    _folders.clear();
    _currentFolderId = null;

    await _saveFolders();
    await _saveBookmarks();
    notifyListeners();
  }
}
