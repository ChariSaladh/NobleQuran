/// Model representing a verse (Ayah) of the Quran
class Verse {
  final int id;
  final int verseNumber;
  final int chapterId;
  final String textArabic;
  final String textSimple;
  final String translation;
  final String transliteration;
  final AudioInfo? audio;
  final List<Word> words;

  Verse({
    required this.id,
    required this.verseNumber,
    required this.chapterId,
    required this.textArabic,
    required this.textSimple,
    required this.translation,
    required this.transliteration,
    this.audio,
    required this.words,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    // Extract text - handle different API response formats
    String arabicText = '';
    String simpleText = '';

    if (json['text'] is Map) {
      final textObj = json['text'] as Map<String, dynamic>;
      arabicText = textObj['arabic'] ?? textObj['text'] ?? '';
      simpleText = textObj['simple'] ?? '';
    } else if (json['text'] is String) {
      arabicText = json['text'] ?? '';
    }

    // Extract translation
    String translationText = '';
    if (json['translations'] is List) {
      final translations = json['translations'] as List;
      if (translations.isNotEmpty && translations[0] is Map) {
        translationText = translations[0]['text'] ?? '';
      }
    } else if (json['translation'] is String) {
      translationText = json['translation'] ?? '';
    } else if (json['translation'] is Map) {
      translationText = json['translation']['message'] ?? '';
    }

    // Extract audio
    AudioInfo? audioInfo;
    if (json['audio'] is Map) {
      final audioData = json['audio'] as Map<String, dynamic>;
      if (audioData['audio_files'] is List) {
        final audioFiles = audioData['audio_files'] as List;
        if (audioFiles.isNotEmpty) {
          audioInfo = AudioInfo.fromJson(audioFiles[0]);
        }
      }
    }

    // Extract words
    List<Word> words = [];
    if (json['words'] is List) {
      words = (json['words'] as List).map((w) => Word.fromJson(w)).toList();
    }

    return Verse(
      id: json['id'] ?? 0,
      verseNumber: json['verse_number'] ?? 0,
      chapterId: json['chapter_id'] ?? 0,
      textArabic: arabicText,
      textSimple: simpleText,
      translation: translationText,
      transliteration: json['transliteration'] is Map
          ? (json['transliteration']['text'] ?? '')
          : '',
      audio: audioInfo,
      words: words,
    );
  }

  /// Create from search result
  factory Verse.fromSearchResult(Map<String, dynamic> json) {
    // Search results have a different structure
    final verseData = json['verse'] as Map<String, dynamic>? ?? json;

    String arabicText = '';
    if (verseData['text'] is Map) {
      arabicText = verseData['text']['arabic'] ?? '';
    } else if (verseData['text'] is String) {
      arabicText = verseData['text'] ?? '';
    }

    String translationText = '';
    if (json['translations'] is List) {
      final translations = json['translations'] as List;
      if (translations.isNotEmpty) {
        translationText = translations[0]['text'] ?? '';
      }
    }

    return Verse(
      id: verseData['id'] ?? 0,
      verseNumber: verseData['verse_number'] ?? 0,
      chapterId: verseData['chapter_id'] ?? 0,
      textArabic: arabicText,
      textSimple: '',
      translation: translationText,
      transliteration: '',
      audio: null,
      words: [],
    );
  }
}

/// Model representing audio information for a verse
class AudioInfo {
  final String audioUrl;
  final String format;
  final int duration;

  AudioInfo({
    required this.audioUrl,
    required this.format,
    required this.duration,
  });

  factory AudioInfo.fromJson(Map<String, dynamic> json) {
    return AudioInfo(
      audioUrl: json['audio_url'] ?? '',
      format: json['format'] ?? '',
      duration: json['duration'] ?? 0,
    );
  }
}

/// Model representing a word in a verse
class Word {
  final int id;
  final String position;
  final String textArabic;
  final String textSimple;
  final String transliteration;
  final String translation;
  final String audioUrl;

  Word({
    required this.id,
    required this.position,
    required this.textArabic,
    required this.textSimple,
    required this.transliteration,
    required this.translation,
    required this.audioUrl,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] ?? 0,
      position: json['position']?.toString() ?? '',
      textArabic: json['text']?['arabic'] ?? json['text'] ?? '',
      textSimple: json['text']?['simple'] ?? '',
      transliteration: json['transliteration']?['text'] ?? '',
      translation: json['translation'] ?? '',
      audioUrl: json['audio']?['audio_url'] ?? '',
    );
  }
}
