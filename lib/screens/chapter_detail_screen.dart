import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/quran_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/progress_provider.dart';
import '../utils/theme.dart';
import '../models/chapter.dart';
import '../models/verse.dart';
import '../widgets/mini_player.dart';

/// Screen showing verses of a specific chapter
class ChapterDetailScreen extends StatefulWidget {
  final Chapter chapter;

  const ChapterDetailScreen({super.key, required this.chapter});

  @override
  State<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends State<ChapterDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load verses for this chapter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuranProvider>().selectChapter(widget.chapter.chapterNumber);
    });
  }

  void _updateProgress(int versesRead) {
    final progressProvider = context.read<ProgressProvider>();
    progressProvider.updateChapterProgress(
      chapterId: widget.chapter.chapterNumber,
      versesRead: versesRead,
      totalVerses: widget.chapter.versesCount,
    );

    // Mark chapter as completed if user has listened to all verses
    if (versesRead >= widget.chapter.versesCount) {
      progressProvider.markChapterCompleted(
        widget.chapter.chapterNumber,
        widget.chapter.versesCount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapter.nameSimple),
        backgroundColor: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.primaryColor,
        actions: [
          Consumer<QuranProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Change Reciter',
                onPressed: () => _showReciterSelector(context, provider),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showChapterInfo,
          ),
        ],
      ),
      body: Consumer<QuranProvider>(
        builder: (context, provider, child) {
          // Update progress when verses are played - track current verse being played
          if (provider.currentPlayingVerseIndex >= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Progress = current verse / total verses
              final versesPlayed = provider.currentPlayingVerseIndex + 1;
              _updateProgress(versesPlayed);
            });
          }

          if (provider.isLoadingVerses) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Loading verses...',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load verses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        provider.selectChapter(widget.chapter.chapterNumber),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Chapter header
              _buildChapterHeader(provider),

              // Mini player when audio is playing
              if (provider.currentVerse != null) const MiniPlayer(),

              // Audio player controls (if playing)
              if (provider.isPlaying) _buildAudioPlayer(provider, isDark),

              // Verses list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.verses.length,
                  itemBuilder: (context, index) {
                    return _buildVerseCard(
                      provider.verses[index],
                      index,
                      provider,
                      isDark,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChapterHeader(QuranProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.chapter.nameArabic,
            style: const TextStyle(
              fontSize: 36,
              fontFamily: 'Arial',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.chapter.nameSimple,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.chapter.versesCount} verses • ${widget.chapter.revelationPlace}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          if (widget.chapter.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.chapter.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(QuranProvider provider, bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(
              provider.isPlaying ? Icons.pause : Icons.play_arrow,
              color: AppTheme.primaryColor,
            ),
            onPressed: () {
              if (provider.isPlaying) {
                provider.pauseAudio();
              } else {
                provider.resumeAudio();
              }
            },
          ),

          // Previous
          IconButton(
            icon: Icon(
              Icons.skip_previous,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
            onPressed: provider.currentPlayingVerseIndex > 0
                ? () => provider.playPreviousVerse()
                : null,
          ),

          // Next
          IconButton(
            icon: Icon(
              Icons.skip_next,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
            onPressed:
                provider.currentPlayingVerseIndex < provider.verses.length - 1
                ? () => provider.playNextVerse()
                : null,
          ),

          // Verse indicator
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verse ${provider.currentPlayingVerseIndex + 1}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                  ),
                ),
                LinearProgressIndicator(
                  value: provider.audioDuration.inMilliseconds > 0
                      ? provider.audioPosition.inMilliseconds /
                            provider.audioDuration.inMilliseconds
                      : 0,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Stop button
          IconButton(
            icon: Icon(
              Icons.stop,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
            onPressed: () => provider.stopAudio(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseCard(
    Verse verse,
    int index,
    QuranProvider provider,
    bool isDark,
  ) {
    final isCurrentlyPlaying = provider.currentPlayingVerseIndex == index;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isCurrentlyPlaying
          ? AppTheme.primaryColor.withOpacity(0.05)
          : (isDark ? AppTheme.darkSurfaceColor : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse header
            Row(
              children: [
                // Verse number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${verse.verseNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const Spacer(),

                // Audio play button
                IconButton(
                  icon: Icon(
                    isCurrentlyPlaying && provider.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  onPressed: () {
                    if (isCurrentlyPlaying) {
                      if (provider.isPlaying) {
                        provider.pauseAudio();
                      } else {
                        provider.resumeAudio();
                      }
                    } else {
                      provider.playVerseAudio(index);
                    }
                  },
                ),

                // Share button
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                  onPressed: () => _shareVerse(verse),
                ),

                // Bookmark button
                Consumer<BookmarkProvider>(
                  builder: (context, bookmarkProvider, _) {
                    final isBookmarked = bookmarkProvider.isBookmarked(
                      verse.chapterId,
                      verse.verseNumber,
                    );
                    return IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                        color: isBookmarked
                            ? AppTheme.accentColor
                            : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary),
                      ),
                      onPressed: () => bookmarkProvider.toggleBookmark(
                        chapterId: verse.chapterId,
                        verseNumber: verse.verseNumber,
                        chapterName: widget.chapter.nameSimple,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Arabic text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                verse.textArabic.isNotEmpty
                    ? verse.textArabic
                    : '﴾${verse.verseNumber}﴿',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: AppConstants.arabicFontSize,
                  fontFamily: 'Arial',
                  color: isDark ? Colors.white : AppTheme.arabicTextColor,
                  height: 1.8,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Simple/Transliteration (optional)
            if (verse.textSimple.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackgroundColor
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  verse.textSimple,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // English translation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.translate,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Translation',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verse.translation,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareVerse(Verse verse) {
    final text =
        '''
${verse.textArabic}

${verse.translation}

— ${widget.chapter.nameSimple} [${widget.chapter.chapterNumber}:${verse.verseNumber}]

Shared from Noble Quran App
''';
    Share.share(text);
  }

  void _showChapterInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.chapter.nameSimple,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.chapter.nameArabic,
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'Arial',
                  color: isDark ? Colors.white : AppTheme.arabicTextColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Verses', '${widget.chapter.versesCount}', isDark),
              _buildInfoRow(
                'Revelation',
                widget.chapter.revelationPlace,
                isDark,
              ),
              _buildInfoRow(
                'Chapter Number',
                '${widget.chapter.chapterNumber}',
                isDark,
              ),
              if (widget.chapter.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('About', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  widget.chapter.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showReciterSelector(BuildContext context, QuranProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Reciter',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.reciters.length,
                  itemBuilder: (context, index) {
                    final reciter = provider.reciters[index];
                    final isSelected = reciter.id == provider.currentReciter.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppTheme.primaryColor
                            : (isDark
                                  ? AppTheme.darkBackgroundColor
                                  : Colors.grey.shade200),
                        child: Text(
                          '${reciter.id}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? AppTheme.darkTextPrimary
                                      : Colors.black),
                          ),
                        ),
                      ),
                      title: Text(
                        reciter.name,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        reciter.nameArabic,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppTheme.primaryColor,
                            )
                          : null,
                      onTap: () {
                        provider.setReciter(reciter);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
