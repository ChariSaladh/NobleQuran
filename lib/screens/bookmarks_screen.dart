import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/quran_provider.dart';
import '../utils/theme.dart';
import 'chapter_detail_screen.dart';

/// Screen to display bookmarked verses with folder support
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.primaryColor,
        elevation: 0,
        actions: [
          Consumer<BookmarkProvider>(
            builder: (context, provider, _) {
              if (provider.bookmarks.isEmpty && provider.folders.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.folder_outlined),
                onPressed: () => _showFolderManager(context),
                tooltip: 'Manage folders',
              );
            },
          ),
          Consumer<BookmarkProvider>(
            builder: (context, provider, _) {
              if (provider.bookmarks.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () => _showClearDialog(context, provider),
                tooltip: 'Clear all',
              );
            },
          ),
        ],
      ),
      body: Consumer<BookmarkProvider>(
        builder: (context, bookmarkProvider, _) {
          // Show folder tabs if there are folders
          if (bookmarkProvider.folders.isNotEmpty) {
            return Column(
              children: [
                // Folder tabs
                _buildFolderTabs(context, bookmarkProvider, isDark),
                // Bookmarks list
                Expanded(
                  child: _buildBookmarksList(context, bookmarkProvider, isDark),
                ),
              ],
            );
          }

          // No folders - show simple list
          return _buildBookmarksList(context, bookmarkProvider, isDark);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.create_new_folder, color: Colors.white),
      ),
    );
  }

  Widget _buildFolderTabs(
    BuildContext context,
    BookmarkProvider provider,
    bool isDark,
  ) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          // All bookmarks tab
          _buildFolderChip(
            context,
            provider,
            null,
            'All',
            Icons.bookmark,
            '#1B7958',
            isDark,
          ),
          // Custom folders
          ...provider.folders.map(
            (folder) => _buildFolderChip(
              context,
              provider,
              folder.id,
              folder.name,
              _getFolderIcon(folder.icon),
              folder.color,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderChip(
    BuildContext context,
    BookmarkProvider provider,
    String? folderId,
    String name,
    IconData icon,
    String colorHex,
    bool isDark,
  ) {
    final isSelected = provider.currentFolderId == folderId;
    final color = _parseColor(colorHex);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(name),
            if (folderId != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${provider.getBookmarkCount(folderId)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: isDark
            ? AppTheme.darkBackgroundColor
            : Colors.grey.shade100,
        selectedColor: color,
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          fontWeight: FontWeight.w500,
        ),
        onSelected: (_) => provider.setCurrentFolder(folderId),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildBookmarksList(
    BuildContext context,
    BookmarkProvider bookmarkProvider,
    bool isDark,
  ) {
    final bookmarks = bookmarkProvider.currentFolderBookmarks;

    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline,
                size: 64,
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              bookmarkProvider.currentFolderId == null
                  ? 'No bookmarks yet'
                  : 'No bookmarks in this folder',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Tap the bookmark icon on any verse to save it here',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Group bookmarks by chapter
    final groupedBookmarks = <int, List<Bookmark>>{};
    for (final bookmark in bookmarks) {
      groupedBookmarks.putIfAbsent(bookmark.chapterId, () => []);
      groupedBookmarks[bookmark.chapterId]!.add(bookmark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedBookmarks.length,
      itemBuilder: (context, index) {
        final chapterId = groupedBookmarks.keys.elementAt(index);
        final chapterBookmarks = groupedBookmarks[chapterId]!;
        final chapterName = chapterBookmarks.first.chapterName;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chapter header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.menu_book,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        chapterName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${chapterBookmarks.length} verse${chapterBookmarks.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bookmarked verses
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: chapterBookmarks.length,
                itemBuilder: (context, verseIndex) {
                  final bookmark = chapterBookmarks[verseIndex];
                  return InkWell(
                    onTap: () => _navigateToChapter(
                      context,
                      bookmark.chapterId,
                      bookmark.verseNumber,
                    ),
                    onLongPress: () => _showBookmarkOptions(context, bookmark),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${bookmark.verseNumber}',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verse ${bookmark.verseNumber}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Added ${_formatDate(bookmark.createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.play_circle_filled,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () => _playVerse(
                              context,
                              bookmark.chapterId,
                              bookmark.verseNumber,
                            ),
                            tooltip: 'Play',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.drive_file_move_outlined,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : Colors.grey,
                            ),
                            onPressed: () =>
                                _showMoveToFolderDialog(context, bookmark),
                            tooltip: 'Move to folder',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : Colors.grey,
                            ),
                            onPressed: () => bookmarkProvider.removeBookmark(
                              bookmark.chapterId,
                              bookmark.verseNumber,
                            ),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedColor = '#1B7958';

    final colors = [
      '#1B7958', // Green
      '#2196F3', // Blue
      '#9C27B0', // Purple
      '#F44336', // Red
      '#FF9800', // Orange
      '#795548', // Brown
      '#607D8B', // Grey
      '#E91E63', // Pink
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Create New Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Folder Name',
                  hintText: 'e.g., Favorite Verses',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.folder),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Color',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _parseColor(
                                    color,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  context.read<BookmarkProvider>().createFolder(
                    name: nameController.text.trim(),
                    color: selectedColor,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderManager(BuildContext context) {
    final bookmarkProvider = context.read<BookmarkProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Manage Folders',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: bookmarkProvider.folders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_off_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No folders yet',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to create a folder',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: bookmarkProvider.folders.length,
                          itemBuilder: (context, index) {
                            final folder = bookmarkProvider.folders[index];
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _parseColor(folder.color),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.folder,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(folder.name),
                              subtitle: Text(
                                '${bookmarkProvider.getBookmarkCount(folder.id)} bookmarks',
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 8),
                                        Text('Rename'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'rename') {
                                    _showRenameFolderDialog(context, folder);
                                  } else if (value == 'delete') {
                                    _showDeleteFolderDialog(context, folder);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRenameFolderDialog(BuildContext context, BookmarkFolder folder) {
    final nameController = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Folder'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                context.read<BookmarkProvider>().renameFolder(
                  folder.id,
                  nameController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(BuildContext context, BookmarkFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? Bookmarks in this folder will be moved to "All Bookmarks".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<BookmarkProvider>().deleteFolder(folder.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMoveToFolderDialog(BuildContext context, Bookmark bookmark) {
    final bookmarkProvider = context.read<BookmarkProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move to Folder',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Option: No folder (All Bookmarks)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bookmark, color: Colors.white),
                ),
                title: const Text('All Bookmarks'),
                trailing: bookmark.folderId == null
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  bookmarkProvider.moveBookmarkToFolder(
                    bookmark.chapterId,
                    bookmark.verseNumber,
                    null,
                  );
                  Navigator.pop(context);
                },
              ),
              // Folder options
              ...bookmarkProvider.folders.map(
                (folder) => ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(folder.color),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder, color: Colors.white),
                  ),
                  title: Text(folder.name),
                  trailing: bookmark.folderId == folder.id
                      ? const Icon(Icons.check, color: AppTheme.primaryColor)
                      : null,
                  onTap: () {
                    bookmarkProvider.moveBookmarkToFolder(
                      bookmark.chapterId,
                      bookmark.verseNumber,
                      folder.id,
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
              if (bookmarkProvider.folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No folders yet. Create a folder first.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showBookmarkOptions(BuildContext context, Bookmark bookmark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Move to Folder'),
              onTap: () {
                Navigator.pop(context);
                _showMoveToFolderDialog(context, bookmark);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Remove Bookmark',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                context.read<BookmarkProvider>().removeBookmark(
                  bookmark.chapterId,
                  bookmark.verseNumber,
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, BookmarkProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Bookmarks'),
        content: const Text(
          'Are you sure you want to remove all bookmarks? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearAllBookmarks();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _playVerse(BuildContext context, int chapterId, int verseNumber) {
    final quranProvider = Provider.of<QuranProvider>(context, listen: false);
    quranProvider.selectChapter(chapterId).then((_) {
      // Find verse index and play
      final verseIndex = quranProvider.verses.indexWhere(
        (v) => v.verseNumber == verseNumber,
      );
      if (verseIndex != -1) {
        quranProvider.playVerseAudio(verseIndex);
      }
    });
  }

  void _navigateToChapter(
    BuildContext context,
    int chapterId,
    int verseNumber,
  ) async {
    final quranProvider = Provider.of<QuranProvider>(context, listen: false);
    await quranProvider.selectChapter(chapterId);
    if (context.mounted && quranProvider.currentChapter != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChapterDetailScreen(chapter: quranProvider.currentChapter!),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getFolderIcon(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'bookmark':
        return Icons.bookmark;
      case 'important':
        return Icons.important_devices;
      case 'prayer':
        return Icons.auto_awesome;
      case 'mosque':
        return Icons.mosque;
      default:
        return Icons.folder;
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
