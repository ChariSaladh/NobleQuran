import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/chapter.dart';
import '../models/verse.dart';
import '../services/quran_api_service.dart';

/// Provider for managing Quran data and audio playback
class QuranProvider extends ChangeNotifier {
  final QuranApiService _apiService = QuranApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Chapters data
  List<Chapter> _chapters = [];
  List<Chapter> get chapters => _chapters;

  // Filtered chapters (for search)
  List<Chapter> _filteredChapters = [];
  List<Chapter> get filteredChapters => _filteredChapters;

  // Current chapter
  Chapter? _currentChapter;
  Chapter? get currentChapter => _currentChapter;

  // Verses data
  List<Verse> _verses = [];
  List<Verse> get verses => _verses;

  // Search results
  List<Verse> _searchResults = [];
  List<Verse> get searchResults => _searchResults;

  // Loading states
  bool _isLoadingChapters = false;
  bool get isLoadingChapters => _isLoadingChapters;

  bool _isLoadingVerses = false;
  bool get isLoadingVerses => _isLoadingVerses;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // Audio states
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _currentPlayingVerseIndex = -1;
  int get currentPlayingVerseIndex => _currentPlayingVerseIndex;

  Duration _audioPosition = Duration.zero;
  Duration get audioPosition => _audioPosition;

  Duration _audioDuration = Duration.zero;
  Duration get audioDuration => _audioDuration;

  // Auto-play next verse
  bool _autoPlayNext = true;
  bool get autoPlayNext => _autoPlayNext;

  // Current playing verse
  Verse? get currentVerse {
    if (_currentPlayingVerseIndex >= 0 &&
        _currentPlayingVerseIndex < _verses.length) {
      return _verses[_currentPlayingVerseIndex];
    }
    return null;
  }

  // Error handling
  String? _error;
  String? get error => _error;

  // Search query
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Chapter search query
  String _chapterSearchQuery = '';
  String get chapterSearchQuery => _chapterSearchQuery;

  QuranProvider() {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      _audioPosition = position;
      notifyListeners();
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _audioDuration = duration;
        notifyListeners();
      }
    });

    // Listen to processing state for auto-play next
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _isPlaying = false;

        // Auto-play next verse if enabled
        if (_autoPlayNext && _currentPlayingVerseIndex < _verses.length - 1) {
          playNextVerse();
        } else {
          _currentPlayingVerseIndex = -1;
        }
        notifyListeners();
      }
    });
  }

  /// Load all chapters
  Future<void> loadChapters() async {
    _isLoadingChapters = true;
    _error = null;
    notifyListeners();

    try {
      _chapters = await _apiService.getChapters();
      _filteredChapters = List.from(_chapters);
    } catch (e) {
      _error = e.toString();
    }

    _isLoadingChapters = false;
    notifyListeners();
  }

  /// Search/filter chapters
  void searchChapters(String query) {
    _chapterSearchQuery = query;
    if (query.isEmpty) {
      _filteredChapters = List.from(_chapters);
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredChapters = _chapters.where((chapter) {
        return chapter.nameSimple.toLowerCase().contains(lowerQuery) ||
            chapter.nameArabic.contains(query) ||
            chapter.nameComplex.toLowerCase().contains(lowerQuery) ||
            chapter.chapterNumber.toString() == query;
      }).toList();
    }
    notifyListeners();
  }

  /// Clear chapter search
  void clearChapterSearch() {
    _chapterSearchQuery = '';
    _filteredChapters = List.from(_chapters);
    notifyListeners();
  }

  /// Select a chapter and load its verses
  Future<void> selectChapter(int chapterId) async {
    _isLoadingVerses = true;
    _error = null;
    _verses = [];
    notifyListeners();

    try {
      _currentChapter = await _apiService.getChapter(chapterId);
      _verses = await _apiService.getChapterVerses(chapterId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoadingVerses = false;
    notifyListeners();
  }

  /// Search verses by query
  Future<void> searchVerses(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _searchQuery = '';
      notifyListeners();
      return;
    }

    _isSearching = true;
    _searchQuery = query;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _apiService.searchVerses(query);
    } catch (e) {
      _error = e.toString();
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    notifyListeners();
  }

  /// Play audio for a specific verse
  Future<void> playVerseAudio(int index) async {
    if (index < 0 || index >= _verses.length) return;

    final verse = _verses[index];

    // Try to get audio from verse or fetch it
    String? audioUrl = verse.audio?.audioUrl;

    if (audioUrl == null || audioUrl.isEmpty) {
      // Fetch audio URL
      audioUrl = await _apiService.getVerseAudio(
        verse.chapterId,
        verse.verseNumber,
      );
    }

    final url = audioUrl;
    if (url.isNotEmpty) {
      _currentPlayingVerseIndex = index;

      // Play audio
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _audioPlayer.play();
      notifyListeners();
    } else {
      _error = 'Audio not available for this verse';
      notifyListeners();
    }
  }

  /// Pause audio
  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
  }

  /// Resume audio
  Future<void> resumeAudio() async {
    await _audioPlayer.play();
  }

  /// Stop audio
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _currentPlayingVerseIndex = -1;
    _audioPosition = Duration.zero;
    _audioDuration = Duration.zero;
    notifyListeners();
  }

  /// Seek to specific position
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Play next verse
  Future<void> playNextVerse() async {
    if (_currentPlayingVerseIndex < _verses.length - 1) {
      await playVerseAudio(_currentPlayingVerseIndex + 1);
    }
  }

  /// Play previous verse
  Future<void> playPreviousVerse() async {
    if (_currentPlayingVerseIndex > 0) {
      await playVerseAudio(_currentPlayingVerseIndex - 1);
    }
  }

  /// Toggle auto-play next
  void toggleAutoPlayNext() {
    _autoPlayNext = !_autoPlayNext;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get list of available reciters
  List<Reciter> get reciters => Reciter.reciters;

  /// Get current reciter
  Reciter get currentReciter => _apiService.currentReciter;

  /// Change reciter
  void setReciter(Reciter reciter) {
    _apiService.setReciter(reciter);
    // Reload verses with new reciter if chapter is loaded
    if (_currentChapter != null) {
      selectChapter(_currentChapter!.chapterNumber);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _apiService.dispose();
    super.dispose();
  }
}
