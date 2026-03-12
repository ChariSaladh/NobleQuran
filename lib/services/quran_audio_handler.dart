import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/verse.dart';
import '../models/chapter.dart';

/// Audio handler for background playback with notification controls
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // Current playback state
  Chapter? _currentChapter;
  List<Verse> _verses = [];
  int _currentIndex = 0;
  bool _isAutoPlaying = true;

  // Getters
  AudioPlayer get player => _player;
  Chapter? get currentChapter => _currentChapter;
  int get currentIndex => _currentIndex;
  bool get isAutoPlaying => _isAutoPlaying;
  List<Verse> get verses => _verses;

  QuranAudioHandler() {
    _init();
  }

  void _init() {
    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      // Broadcast state to system
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            state.playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[state.processingState]!,
          playing: state.playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
        ),
      );

      // Auto-play next verse when current finishes
      if (state.processingState == ProcessingState.completed &&
          _isAutoPlaying) {
        playNext();
      }
    });
  }

  /// Set the playlist and start playing
  Future<void> setPlaylist({
    required Chapter chapter,
    required List<Verse> verses,
    required int startIndex,
  }) async {
    _currentChapter = chapter;
    _verses = verses;
    _currentIndex = startIndex;

    // Create audio sources from verses
    final sources = <AudioSource>[];
    for (int i = 0; i < verses.length; i++) {
      final v = verses[i];
      if (v.audio?.audioUrl.isNotEmpty == true) {
        sources.add(
          AudioSource.uri(
            Uri.parse(v.audio!.audioUrl),
            tag: MediaItem(
              id: '${v.chapterId}:${v.verseNumber}',
              title: 'Verse ${v.verseNumber}',
              artist: chapter.nameSimple,
              album: 'Noble Quran',
              duration: const Duration(minutes: 1),
            ),
          ),
        );
      }
    }

    if (sources.isEmpty) return;

    final playlist = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(playlist, initialIndex: startIndex);

    _updateMediaItem();
  }

  void _updateMediaItem() {
    if (_verses.isEmpty || _currentIndex >= _verses.length) return;

    final verse = _verses[_currentIndex];
    mediaItem.add(
      MediaItem(
        id: '${verse.chapterId}:${verse.verseNumber}',
        title: 'Verse ${verse.verseNumber}',
        artist: _currentChapter?.nameSimple ?? 'Noble Quran',
        album: 'Surah ${_currentChapter?.nameArabic ?? ""}',
        duration: const Duration(minutes: 1),
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> playNext() async {
    if (_currentIndex < _verses.length - 1) {
      await _player.seekToNext();
      _currentIndex = _player.currentIndex ?? _currentIndex;
      _updateMediaItem();
    }
  }

  Future<void> playPrevious() async {
    if (_currentIndex > 0) {
      await _player.seekToPrevious();
      _currentIndex = _player.currentIndex ?? _currentIndex;
      _updateMediaItem();
    }
  }

  void setAutoPlay(bool value) {
    _isAutoPlaying = value;
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
