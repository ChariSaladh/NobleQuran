import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quran_provider.dart';
import '../providers/progress_provider.dart';
import '../utils/theme.dart';
import '../models/chapter.dart';
import 'chapter_detail_screen.dart';

/// Library screen showing all chapters of the Quran
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filterType = 'all'; // all, meccan, medinan
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load chapters if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<QuranProvider>();
      if (provider.chapters.isEmpty) {
        provider.loadChapters();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Library'),
        backgroundColor: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.primaryColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
              onChanged: (value) {
                context.read<QuranProvider>().searchChapters(value);
              },
              decoration: InputDecoration(
                hintText: 'Search chapters (English or Arabic)...',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          context.read<QuranProvider>().clearChapterSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(),

          // Chapters list
          Expanded(
            child: Consumer<QuranProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingChapters) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.chapters.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load chapters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => provider.loadChapters(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // Get chapters based on search
                final chaptersToShow = provider.chapterSearchQuery.isEmpty
                    ? provider.chapters
                    : provider.filteredChapters;

                final filteredChapters = _filterChapters(chaptersToShow);

                if (filteredChapters.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.chapterSearchQuery.isEmpty
                              ? 'No chapters found'
                              : 'No chapters match "${provider.chapterSearchQuery}"',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredChapters.length,
                  itemBuilder: (context, index) {
                    return _buildChapterCard(filteredChapters[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.primaryColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            _buildFilterChip('All', 'all', isDark),
            const SizedBox(width: 8),
            _buildFilterChip('Meccan', 'meccan', isDark),
            const SizedBox(width: 8),
            _buildFilterChip('Medinan', 'medinan', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? AppTheme.darkSurfaceColor : AppTheme.primaryColor)
                : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  List<Chapter> _filterChapters(List<Chapter> chapters) {
    return chapters.where((chapter) {
      // Apply revelation place filter
      if (_filterType != 'all') {
        if (_filterType == 'meccan' && chapter.revelationPlace != 'Meccan') {
          return false;
        }
        if (_filterType == 'medinan' && chapter.revelationPlace != 'Medinan') {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildChapterCard(Chapter chapter) {
    return Consumer<ProgressProvider>(
      builder: (context, progressProvider, child) {
        final progress = progressProvider.getChapterProgress(
          chapter.chapterNumber,
        );
        final isCompleted = progress?.isCompleted ?? false;
        final progressPercent = progress?.progressPercentage ?? 0;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChapterDetailScreen(chapter: chapter),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Chapter number
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withAlpha(25)
                              : AppTheme.primaryColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.green)
                              : Text(
                                  '${chapter.chapterNumber}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted
                                        ? Colors.green
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Chapter info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.nameSimple,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chapter.revelationPlace == 'Meccan'
                                        ? Colors.orange.withAlpha(25)
                                        : Colors.green.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    chapter.revelationPlace,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: chapter.revelationPlace == 'Meccan'
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${chapter.versesCount} verses',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Arabic name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            chapter.nameArabic,
                            style: TextStyle(
                              fontSize: 24,
                              fontFamily: 'Arial',
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.arabicTextColor,
                            ),
                          ),
                          if (chapter.bismillahPre)
                            Text(
                              'بِسْمِ',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Arial',
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
                // Progress bar at bottom
                if (progress != null && !isCompleted)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: LinearProgressIndicator(
                        value: progressPercent / 100,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor.withAlpha(180),
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
