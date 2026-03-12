import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chapter.dart';
import '../models/verse.dart';

/// Available reciters
class Reciter {
  final int id;
  final String identifier;
  final String name;
  final String nameArabic;

  const Reciter({
    required this.id,
    required this.identifier,
    required this.name,
    required this.nameArabic,
  });

  static const List<Reciter> reciters = [
    Reciter(
      id: 1,
      identifier: 'ar.alafasy',
      name: 'Mishary Rashid Alafasy',
      nameArabic: 'مشاري بن راشد العفاسي',
    ),
    Reciter(
      id: 2,
      identifier: 'ar.husary',
      name: 'Mahmoud Khalil Al-Husary',
      nameArabic: 'محمود خليل الحصري',
    ),
    Reciter(
      id: 3,
      identifier: 'ar.husary_muallim',
      name: 'Muhammad Al-Husary (Muallim)',
      nameArabic: 'محمد الحصري (معلم)',
    ),
    Reciter(
      id: 4,
      identifier: 'ar.abdulbasit',
      name: 'Abdul Basit',
      nameArabic: 'عبدالباسط عبد الصمد',
    ),
    Reciter(
      id: 5,
      identifier: 'ar.shaatree',
      name: 'Abu Bakr Al-Shatri',
      nameArabic: 'أبي بكر الشاطري',
    ),
    Reciter(
      id: 6,
      identifier: 'ar.ayyub',
      name: 'Ahmad bin Ali Al-Ayyoobi',
      nameArabic: 'أحمد بن علي العيوبي',
    ),
    Reciter(
      id: 7,
      identifier: 'ar.minshawi',
      name: 'Mohamed Al-Minshawi',
      nameArabic: 'محمد المنشاوي',
    ),
    Reciter(
      id: 8,
      identifier: 'ar.qumbah',
      name: 'Al-Kaaba Recitation',
      nameArabic: 'قارئ الكعبة',
    ),
  ];

  static Reciter get defaultReciter => reciters[0];
}

/// Service class for interacting with the AlQuran.cloud API
class QuranApiService {
  static const String _baseUrl = 'https://api.alquran.cloud/v1';

  final http.Client _client;
  Reciter _currentReciter = Reciter.defaultReciter;

  QuranApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Set the current reciter
  void setReciter(Reciter reciter) {
    _currentReciter = reciter;
  }

  /// Get current reciter
  Reciter get currentReciter => _currentReciter;

  /// Fetches all chapters
  Future<List<Chapter>> getChapters() async {
    try {
      return _getChaptersList();
    } catch (e) {
      return _getChaptersList();
    }
  }

  /// Fetches a specific chapter
  Future<Chapter> getChapter(int chapterId) async {
    final chapters = _getChaptersList();
    return chapters.firstWhere(
      (c) => c.chapterNumber == chapterId,
      orElse: () => chapters.first,
    );
  }

  /// Get verses for a specific chapter
  Future<List<Verse>> getChapterVerses(int chapterId, {int limit = 300}) async {
    try {
      // Get Arabic verses with audio from selected reciter
      final arabicResponse = await _client.get(
        Uri.parse('$_baseUrl/surah/$chapterId/${_currentReciter.identifier}'),
        headers: {'Accept': 'application/json'},
      );

      // Get English translation
      final englishResponse = await _client.get(
        Uri.parse('$_baseUrl/surah/$chapterId/en.sahih'),
        headers: {'Accept': 'application/json'},
      );

      if (arabicResponse.statusCode == 200) {
        final arabicData = json.decode(arabicResponse.body);
        final arabicVerses =
            arabicData['data']['ayahs'] as List<dynamic>? ?? [];

        List<Verse> verses = [];
        Map<int, String> englishTranslations = {};

        // Get English translations
        if (englishResponse.statusCode == 200) {
          final englishData = json.decode(englishResponse.body);
          final englishVerses =
              englishData['data']['ayahs'] as List<dynamic>? ?? [];
          for (var verse in englishVerses) {
            englishTranslations[verse['numberInSurah'] as int] =
                verse['text'] ?? '';
          }
        }

        for (var verse in arabicVerses) {
          final verseNum = verse['numberInSurah'] as int;
          final audioUrl = verse['audio'] as String? ?? '';

          verses.add(
            Verse(
              id: verse['number'] as int,
              verseNumber: verseNum,
              chapterId: chapterId,
              textArabic: verse['text'] ?? '',
              textSimple: '',
              translation: englishTranslations[verseNum] ?? '',
              transliteration: '',
              audio: audioUrl.isNotEmpty
                  ? AudioInfo(
                      audioUrl: audioUrl,
                      format: 'audio/mp3',
                      duration: 0,
                    )
                  : null,
              words: [],
            ),
          );
        }

        return verses;
      } else {
        return _getSampleVerses(chapterId);
      }
    } catch (e) {
      return _getSampleVerses(chapterId);
    }
  }

  /// Search verses
  Future<List<Verse>> searchVerses(String query, {int limit = 50}) async {
    try {
      // Use the correct API endpoint with English translation
      final response = await _client.get(
        Uri.parse('$_baseUrl/search/$query/en.sahih'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check if the response has results
        if (data['data'] == null) {
          return [];
        }

        final results = data['data']['matches'] as List<dynamic>? ?? [];

        if (results.isEmpty) {
          // Try alternative search with different translations
          return await _searchWithAlternativeTranslation(query, limit);
        }

        return results.take(limit).map((r) {
          return Verse(
            id: r['number'] as int? ?? 0,
            verseNumber: r['numberInSurah'] as int? ?? 0,
            chapterId: r['surah']['number'] as int? ?? 0,
            textArabic: r['text'] ?? '',
            textSimple: '',
            translation: r['translation'] ?? r['transliteration'] ?? '',
            transliteration: '',
            audio: null,
            words: [],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  /// Search with alternative translation if primary fails
  Future<List<Verse>> _searchWithAlternativeTranslation(
    String query,
    int limit,
  ) async {
    try {
      // Try with another translation
      final response = await _client.get(
        Uri.parse('$_baseUrl/search/$query/en.pickthall'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data']['matches'] as List<dynamic>? ?? [];

        return results.take(limit).map((r) {
          return Verse(
            id: r['number'] as int? ?? 0,
            verseNumber: r['numberInSurah'] as int? ?? 0,
            chapterId: r['surah']['number'] as int? ?? 0,
            textArabic: r['text'] ?? '',
            textSimple: '',
            translation: r['translation'] ?? r['transliteration'] ?? '',
            transliteration: '',
            audio: null,
            words: [],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Alternative search error: $e');
      return [];
    }
  }

  /// Search chapters
  Future<List<Chapter>> searchChapters(String query) async {
    final chapters = _getChaptersList();
    if (query.isEmpty) return chapters;

    final lowerQuery = query.toLowerCase();
    return chapters.where((chapter) {
      return chapter.nameSimple.toLowerCase().contains(lowerQuery) ||
          chapter.nameArabic.contains(query) ||
          chapter.nameComplex.toLowerCase().contains(lowerQuery) ||
          chapter.chapterNumber.toString() == query;
    }).toList();
  }

  /// Get audio URL for a specific verse
  Future<String> getVerseAudio(int chapterId, int verseNumber) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/surah/$chapterId/${_currentReciter.identifier}'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final verses = data['data']['ayahs'] as List<dynamic>? ?? [];

        for (var verse in verses) {
          if (verse['numberInSurah'] == verseNumber) {
            return verse['audio'] as String? ?? '';
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Get specific verse
  Future<Verse> getVerse(int chapterId, int verseNumber) async {
    final verses = await getChapterVerses(chapterId);
    return verses.firstWhere(
      (v) => v.verseNumber == verseNumber,
      orElse: () => verses.first,
    );
  }

  void dispose() {
    _client.close();
  }

  /// All 114 chapters with proper data
  List<Chapter> _getChaptersList() {
    return [
      Chapter(
        id: 1,
        nameSimple: 'Al-Fatiha',
        nameArabic: 'الفاتحة',
        nameComplex: 'Al-Fātiḥah',
        versesCount: 7,
        chapterNumber: 1,
        revelationPlace: 'Meccan',
        bismillahPre: false,
        description: 'The Opening',
      ),
      Chapter(
        id: 2,
        nameSimple: 'Al-Baqarah',
        nameArabic: 'البقرة',
        nameComplex: 'Al-Baqarah',
        versesCount: 286,
        chapterNumber: 2,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Cow',
      ),
      Chapter(
        id: 3,
        nameSimple: 'Ali Imran',
        nameArabic: 'آل عمران',
        nameComplex: 'Āl ʿImrān',
        versesCount: 200,
        chapterNumber: 3,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Family of Imran',
      ),
      Chapter(
        id: 4,
        nameSimple: 'An-Nisa',
        nameArabic: 'النساء',
        nameComplex: 'An-Nisāʾ',
        versesCount: 176,
        chapterNumber: 4,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Women',
      ),
      Chapter(
        id: 5,
        nameSimple: 'Al-Ma\'idah',
        nameArabic: 'المائدة',
        nameComplex: 'Al-Māʾidah',
        versesCount: 120,
        chapterNumber: 5,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Table Spread',
      ),
      Chapter(
        id: 6,
        nameSimple: 'Al-An\'am',
        nameArabic: 'الأنعام',
        nameComplex: 'Al-Anʿām',
        versesCount: 165,
        chapterNumber: 6,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Cattle',
      ),
      Chapter(
        id: 7,
        nameSimple: 'Al-A\'raf',
        nameArabic: 'الأعراف',
        nameComplex: 'Al-Aʿrāf',
        versesCount: 206,
        chapterNumber: 7,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Heights',
      ),
      Chapter(
        id: 8,
        nameSimple: 'Al-Anfal',
        nameArabic: 'الأنفال',
        nameComplex: 'Al-Anfāl',
        versesCount: 75,
        chapterNumber: 8,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Spoils of War',
      ),
      Chapter(
        id: 9,
        nameSimple: 'At-Tawbah',
        nameArabic: 'التوبة',
        nameComplex: 'At-Tawbah',
        versesCount: 129,
        chapterNumber: 9,
        revelationPlace: 'Medinan',
        bismillahPre: false,
        description: 'The Repentance',
      ),
      Chapter(
        id: 10,
        nameSimple: 'Yunus',
        nameArabic: 'يونس',
        nameComplex: 'Yūnus',
        versesCount: 109,
        chapterNumber: 10,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Jonah',
      ),
      Chapter(
        id: 11,
        nameSimple: 'Hud',
        nameArabic: 'هود',
        nameComplex: 'Hūd',
        versesCount: 123,
        chapterNumber: 11,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Hud',
      ),
      Chapter(
        id: 12,
        nameSimple: 'Yusuf',
        nameArabic: 'يوسف',
        nameComplex: 'Yūsuf',
        versesCount: 111,
        chapterNumber: 12,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Joseph',
      ),
      Chapter(
        id: 13,
        nameSimple: 'Ar-Ra\'d',
        nameArabic: 'الرعد',
        nameComplex: 'Ar-Raʿd',
        versesCount: 43,
        chapterNumber: 13,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Thunder',
      ),
      Chapter(
        id: 14,
        nameSimple: 'Ibrahim',
        nameArabic: 'ابراهيم',
        nameComplex: 'Ibrāhīm',
        versesCount: 52,
        chapterNumber: 14,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Abraham',
      ),
      Chapter(
        id: 15,
        nameSimple: 'Al-Hijr',
        nameArabic: 'الحجر',
        nameComplex: 'Al-Ḥijr',
        versesCount: 99,
        chapterNumber: 15,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Rocky Tract',
      ),
      Chapter(
        id: 16,
        nameSimple: 'An-Nahl',
        nameArabic: 'النحل',
        nameComplex: 'An-Naḥl',
        versesCount: 128,
        chapterNumber: 16,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Bee',
      ),
      Chapter(
        id: 17,
        nameSimple: 'Al-Isra',
        nameArabic: 'الإسراء',
        nameComplex: 'Al-Isrāʾ',
        versesCount: 111,
        chapterNumber: 17,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Night Journey',
      ),
      Chapter(
        id: 18,
        nameSimple: 'Al-Kahf',
        nameArabic: 'الكهف',
        nameComplex: 'Al-Kahf',
        versesCount: 110,
        chapterNumber: 18,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Cave',
      ),
      Chapter(
        id: 19,
        nameSimple: 'Maryam',
        nameArabic: 'مريم',
        nameComplex: 'Maryam',
        versesCount: 98,
        chapterNumber: 19,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Mary',
      ),
      Chapter(
        id: 20,
        nameSimple: 'Ta-Ha',
        nameArabic: 'طه',
        nameComplex: 'Ṭā-Hā',
        versesCount: 135,
        chapterNumber: 20,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Ta-Ha',
      ),
      Chapter(
        id: 21,
        nameSimple: 'Al-Anbiya',
        nameArabic: 'الأنبياء',
        nameComplex: 'Al-Anbiyāʾ',
        versesCount: 112,
        chapterNumber: 21,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Prophets',
      ),
      Chapter(
        id: 22,
        nameSimple: 'Al-Hajj',
        nameArabic: 'الحج',
        nameComplex: 'Al-Ḥajj',
        versesCount: 78,
        chapterNumber: 22,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Pilgrimage',
      ),
      Chapter(
        id: 23,
        nameSimple: 'Al-Mu\'minun',
        nameArabic: 'المؤمنون',
        nameComplex: 'Al-Muʾminūn',
        versesCount: 118,
        chapterNumber: 23,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Believers',
      ),
      Chapter(
        id: 24,
        nameSimple: 'An-Nur',
        nameArabic: 'النور',
        nameComplex: 'An-Nūr',
        versesCount: 64,
        chapterNumber: 24,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Light',
      ),
      Chapter(
        id: 25,
        nameSimple: 'Al-Furqan',
        nameArabic: 'الفرقان',
        nameComplex: 'Al-Furqān',
        versesCount: 77,
        chapterNumber: 25,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Criterion',
      ),
      Chapter(
        id: 26,
        nameSimple: 'Ash-Shu\'ara',
        nameArabic: 'الشعراء',
        nameComplex: 'Ash-Shuʿarāʾ',
        versesCount: 227,
        chapterNumber: 26,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Poets',
      ),
      Chapter(
        id: 27,
        nameSimple: 'An-Naml',
        nameArabic: 'النمل',
        nameComplex: 'An-Naml',
        versesCount: 93,
        chapterNumber: 27,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Ant',
      ),
      Chapter(
        id: 28,
        nameSimple: 'Al-Qasas',
        nameArabic: 'القصص',
        nameComplex: 'Al-Qaṣaṣ',
        versesCount: 88,
        chapterNumber: 28,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Stories',
      ),
      Chapter(
        id: 29,
        nameSimple: 'Al-\'Ankabut',
        nameArabic: 'العنكبوت',
        nameComplex: 'Al-ʿAnkabūt',
        versesCount: 69,
        chapterNumber: 29,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Spider',
      ),
      Chapter(
        id: 30,
        nameSimple: 'Ar-Rum',
        nameArabic: 'الروم',
        nameComplex: 'Ar-Rūm',
        versesCount: 60,
        chapterNumber: 30,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Romans',
      ),
      Chapter(
        id: 31,
        nameSimple: 'Luqman',
        nameArabic: 'لقمان',
        nameComplex: 'Luqmān',
        versesCount: 34,
        chapterNumber: 31,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Luqman',
      ),
      Chapter(
        id: 32,
        nameSimple: 'As-Sajdah',
        nameArabic: 'السجدة',
        nameComplex: 'As-Sajdah',
        versesCount: 30,
        chapterNumber: 32,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Prostration',
      ),
      Chapter(
        id: 33,
        nameSimple: 'Al-Ahzab',
        nameArabic: 'الأحزاب',
        nameComplex: 'Al-Aḥzāb',
        versesCount: 73,
        chapterNumber: 33,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Confederates',
      ),
      Chapter(
        id: 34,
        nameSimple: 'Saba',
        nameArabic: 'سبأ',
        nameComplex: 'Sabaʾ',
        versesCount: 54,
        chapterNumber: 34,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Sheba',
      ),
      Chapter(
        id: 35,
        nameSimple: 'Fatir',
        nameArabic: 'فاطر',
        nameComplex: 'Fāṭir',
        versesCount: 45,
        chapterNumber: 35,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Originator',
      ),
      Chapter(
        id: 36,
        nameSimple: 'Ya-Sin',
        nameArabic: 'يس',
        nameComplex: 'Yā-Sīn',
        versesCount: 83,
        chapterNumber: 36,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Ya-Sin',
      ),
      Chapter(
        id: 37,
        nameSimple: 'As-Saffat',
        nameArabic: 'الصافات',
        nameComplex: 'Aṣ-Ṣāffāt',
        versesCount: 182,
        chapterNumber: 37,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Those Who Arrange',
      ),
      Chapter(
        id: 38,
        nameSimple: 'Sad',
        nameArabic: 'ص',
        nameComplex: 'Ṣād',
        versesCount: 88,
        chapterNumber: 38,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Sad',
      ),
      Chapter(
        id: 39,
        nameSimple: 'Az-Zumar',
        nameArabic: 'الزمر',
        nameComplex: 'Az-Zumar',
        versesCount: 75,
        chapterNumber: 39,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Groups',
      ),
      Chapter(
        id: 40,
        nameSimple: 'Ghafir',
        nameArabic: 'غافر',
        nameComplex: 'Ghāfir',
        versesCount: 85,
        chapterNumber: 40,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Forgiver',
      ),
      Chapter(
        id: 41,
        nameSimple: 'Fussilat',
        nameArabic: 'فصلت',
        nameComplex: 'Fuṣṣilat',
        versesCount: 54,
        chapterNumber: 41,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Explained',
      ),
      Chapter(
        id: 42,
        nameSimple: 'Ash-Shura',
        nameArabic: 'الشورى',
        nameComplex: 'Ash-Shūrā',
        versesCount: 53,
        chapterNumber: 42,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Consultation',
      ),
      Chapter(
        id: 43,
        nameSimple: 'Az-Zukhruf',
        nameArabic: 'الزخرف',
        nameComplex: 'Az-Zukhruf',
        versesCount: 89,
        chapterNumber: 43,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Ornaments',
      ),
      Chapter(
        id: 44,
        nameSimple: 'Ad-Dukhan',
        nameArabic: 'الدخان',
        nameComplex: 'Ad-Dukhān',
        versesCount: 59,
        chapterNumber: 44,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Smoke',
      ),
      Chapter(
        id: 45,
        nameSimple: 'Al-Jathiyah',
        nameArabic: 'الجاثية',
        nameComplex: 'Al-Jāthiyah',
        versesCount: 37,
        chapterNumber: 45,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Crouching',
      ),
      Chapter(
        id: 46,
        nameSimple: 'Al-Ahqaf',
        nameArabic: 'الأحقاف',
        nameComplex: 'Al-Aḥqāf',
        versesCount: 35,
        chapterNumber: 46,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Dunes',
      ),
      Chapter(
        id: 47,
        nameSimple: 'Muhammad',
        nameArabic: 'محمد',
        nameComplex: 'Muḥammad',
        versesCount: 38,
        chapterNumber: 47,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'Muhammad',
      ),
      Chapter(
        id: 48,
        nameSimple: 'Al-Fath',
        nameArabic: 'الفتح',
        nameComplex: 'Al-Fatḥ',
        versesCount: 29,
        chapterNumber: 48,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Victory',
      ),
      Chapter(
        id: 49,
        nameSimple: 'Al-Hujurat',
        nameArabic: 'الحجرات',
        nameComplex: 'Al-Ḥujurāt',
        versesCount: 18,
        chapterNumber: 49,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Private Apartments',
      ),
      Chapter(
        id: 50,
        nameSimple: 'Qaf',
        nameArabic: 'ق',
        nameComplex: 'Qāf',
        versesCount: 45,
        chapterNumber: 50,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Qaf',
      ),
      Chapter(
        id: 51,
        nameSimple: 'Ad-Dariyat',
        nameArabic: 'الذاريات',
        nameComplex: 'Adh-Dhāriyāt',
        versesCount: 60,
        chapterNumber: 51,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Scatterers',
      ),
      Chapter(
        id: 52,
        nameSimple: 'At-Tur',
        nameArabic: 'الطور',
        nameComplex: 'Aṭ-Ṭūr',
        versesCount: 49,
        chapterNumber: 52,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Mount',
      ),
      Chapter(
        id: 53,
        nameSimple: 'An-Najm',
        nameArabic: 'النجم',
        nameComplex: 'An-Najm',
        versesCount: 62,
        chapterNumber: 53,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Star',
      ),
      Chapter(
        id: 54,
        nameSimple: 'Al-Qamar',
        nameArabic: 'القمر',
        nameComplex: 'Al-Qamar',
        versesCount: 55,
        chapterNumber: 54,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Moon',
      ),
      Chapter(
        id: 55,
        nameSimple: 'Ar-Rahman',
        nameArabic: 'الرحمن',
        nameComplex: 'Ar-Raḥmān',
        versesCount: 78,
        chapterNumber: 55,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Most Merciful',
      ),
      Chapter(
        id: 56,
        nameSimple: 'Al-Waqi\'ah',
        nameArabic: 'الواقعة',
        nameComplex: 'Al-Wāqiʿah',
        versesCount: 96,
        chapterNumber: 56,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Inevitable',
      ),
      Chapter(
        id: 57,
        nameSimple: 'Al-Hadid',
        nameArabic: 'الحديد',
        nameComplex: 'Al-Ḥadīd',
        versesCount: 29,
        chapterNumber: 57,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Iron',
      ),
      Chapter(
        id: 58,
        nameSimple: 'Al-Mujadilah',
        nameArabic: 'المجادلة',
        nameComplex: 'Al-Mujādilah',
        versesCount: 22,
        chapterNumber: 58,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Argument',
      ),
      Chapter(
        id: 59,
        nameSimple: 'Al-Hashr',
        nameArabic: 'الحشر',
        nameComplex: 'Al-Ḥashr',
        versesCount: 24,
        chapterNumber: 59,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Exile',
      ),
      Chapter(
        id: 60,
        nameSimple: 'Al-Mumtahanah',
        nameArabic: 'الممتحنة',
        nameComplex: 'Al-Mumtaḥanah',
        versesCount: 13,
        chapterNumber: 60,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Tested',
      ),
      Chapter(
        id: 61,
        nameSimple: 'As-Saf',
        nameArabic: 'الصف',
        nameComplex: 'Aṣ-Ṣaf',
        versesCount: 14,
        chapterNumber: 61,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Ranks',
      ),
      Chapter(
        id: 62,
        nameSimple: 'Al-Jumu\'ah',
        nameArabic: 'الجمعة',
        nameComplex: 'Al-Jumuʿah',
        versesCount: 11,
        chapterNumber: 62,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'Friday',
      ),
      Chapter(
        id: 63,
        nameSimple: 'Al-Munafiqun',
        nameArabic: 'المنافقون',
        nameComplex: 'Al-Munāfiqūn',
        versesCount: 11,
        chapterNumber: 63,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Hypocrites',
      ),
      Chapter(
        id: 64,
        nameSimple: 'At-Taghabun',
        nameArabic: 'التغابن',
        nameComplex: 'At-Taghābun',
        versesCount: 18,
        chapterNumber: 64,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Mutual Disappointment',
      ),
      Chapter(
        id: 65,
        nameSimple: 'At-Talaq',
        nameArabic: 'الطلاق',
        nameComplex: 'Aṭ-Ṭalāq',
        versesCount: 12,
        chapterNumber: 65,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'Divorce',
      ),
      Chapter(
        id: 66,
        nameSimple: 'At-Tahrim',
        nameArabic: 'التحريم',
        nameComplex: 'At-Taḥrīm',
        versesCount: 12,
        chapterNumber: 66,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Prohibition',
      ),
      Chapter(
        id: 67,
        nameSimple: 'Al-Mulk',
        nameArabic: 'الملك',
        nameComplex: 'Al-Mulk',
        versesCount: 30,
        chapterNumber: 67,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Sovereignty',
      ),
      Chapter(
        id: 68,
        nameSimple: 'Al-Qalam',
        nameArabic: 'القلم',
        nameComplex: 'Al-Qalam',
        versesCount: 52,
        chapterNumber: 68,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Pen',
      ),
      Chapter(
        id: 69,
        nameSimple: 'Al-Haqqah',
        nameArabic: 'الحاقة',
        nameComplex: 'Al-Ḥāqqah',
        versesCount: 52,
        chapterNumber: 69,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Reality',
      ),
      Chapter(
        id: 70,
        nameSimple: 'Al-Ma\'arij',
        nameArabic: 'المعارج',
        nameComplex: 'Al-Maʿārij',
        versesCount: 44,
        chapterNumber: 70,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Ascending Stairways',
      ),
      Chapter(
        id: 71,
        nameSimple: 'Nuh',
        nameArabic: 'نوح',
        nameComplex: 'Nūḥ',
        versesCount: 28,
        chapterNumber: 71,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Noah',
      ),
      Chapter(
        id: 72,
        nameSimple: 'Al-Jinn',
        nameArabic: 'الجن',
        nameComplex: 'Al-Jinn',
        versesCount: 28,
        chapterNumber: 72,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Jinn',
      ),
      Chapter(
        id: 73,
        nameSimple: 'Al-Muzzammil',
        nameArabic: 'المزمل',
        nameComplex: 'Al-Muzzammil',
        versesCount: 20,
        chapterNumber: 73,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Enshrouded One',
      ),
      Chapter(
        id: 74,
        nameSimple: 'Al-Muddaththir',
        nameArabic: 'المدثر',
        nameComplex: 'Al-Muddaththir',
        versesCount: 56,
        chapterNumber: 74,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Cloaked One',
      ),
      Chapter(
        id: 75,
        nameSimple: 'Al-Qiyamah',
        nameArabic: 'القيامة',
        nameComplex: 'Al-Qiyāmah',
        versesCount: 40,
        chapterNumber: 75,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Resurrection',
      ),
      Chapter(
        id: 76,
        nameSimple: 'Al-Insan',
        nameArabic: 'الإنسان',
        nameComplex: 'Al-Insān',
        versesCount: 31,
        chapterNumber: 76,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'Man',
      ),
      Chapter(
        id: 77,
        nameSimple: 'Al-Mursalat',
        nameArabic: 'المرسلات',
        nameComplex: 'Al-Mursalāt',
        versesCount: 50,
        chapterNumber: 77,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Sent Ones',
      ),
      Chapter(
        id: 78,
        nameSimple: 'An-Naba',
        nameArabic: 'النبأ',
        nameComplex: 'An-Nabaʾ',
        versesCount: 40,
        chapterNumber: 78,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Announcement',
      ),
      Chapter(
        id: 79,
        nameSimple: 'An-Nazi\'at',
        nameArabic: 'النازعات',
        nameComplex: 'An-Nāziʿāt',
        versesCount: 46,
        chapterNumber: 79,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Those Who Drag Forth',
      ),
      Chapter(
        id: 80,
        nameSimple: 'Abasa',
        nameArabic: 'عبس',
        nameComplex: 'ʿAbasa',
        versesCount: 42,
        chapterNumber: 80,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'He Frowned',
      ),
      Chapter(
        id: 81,
        nameSimple: 'At-Takwir',
        nameArabic: 'التكوير',
        nameComplex: 'At-Takwīr',
        versesCount: 29,
        chapterNumber: 81,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Overthrowing',
      ),
      Chapter(
        id: 82,
        nameSimple: 'Al-Infitar',
        nameArabic: 'الانفطار',
        nameComplex: 'Al-Infiṭār',
        versesCount: 19,
        chapterNumber: 82,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Cleaving',
      ),
      Chapter(
        id: 83,
        nameSimple: 'Al-Mutaffifin',
        nameArabic: 'المطففين',
        nameComplex: 'Al-Muṭaffifīn',
        versesCount: 36,
        chapterNumber: 83,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Defrauding',
      ),
      Chapter(
        id: 84,
        nameSimple: 'Al-Inshiqaq',
        nameArabic: 'الانشقاق',
        nameComplex: 'Al-Inshiqāq',
        versesCount: 25,
        chapterNumber: 84,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Splitting',
      ),
      Chapter(
        id: 85,
        nameSimple: 'Al-Buruj',
        nameArabic: 'البروج',
        nameComplex: 'Al-Burūj',
        versesCount: 22,
        chapterNumber: 85,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Constellations',
      ),
      Chapter(
        id: 86,
        nameSimple: 'At-Tariq',
        nameArabic: 'الطارق',
        nameComplex: 'Aṭ-Ṭāriq',
        versesCount: 17,
        chapterNumber: 86,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Morning Star',
      ),
      Chapter(
        id: 87,
        nameSimple: 'Al-A\'la',
        nameArabic: 'الأعلى',
        nameComplex: 'Al-Aʿlā',
        versesCount: 19,
        chapterNumber: 87,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Most High',
      ),
      Chapter(
        id: 88,
        nameSimple: 'Al-Ghashiyah',
        nameArabic: 'الغاشية',
        nameComplex: 'Al-Ghāshiyah',
        versesCount: 26,
        chapterNumber: 88,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Overwhelming',
      ),
      Chapter(
        id: 89,
        nameSimple: 'Al-Fajr',
        nameArabic: 'الفجر',
        nameComplex: 'Al-Fajr',
        versesCount: 30,
        chapterNumber: 89,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Dawn',
      ),
      Chapter(
        id: 90,
        nameSimple: 'Al-Balad',
        nameArabic: 'البلد',
        nameComplex: 'Al-Balad',
        versesCount: 20,
        chapterNumber: 90,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The City',
      ),
      Chapter(
        id: 91,
        nameSimple: 'Ash-Shams',
        nameArabic: 'الشمس',
        nameComplex: 'Ash-Shams',
        versesCount: 15,
        chapterNumber: 91,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Sun',
      ),
      Chapter(
        id: 92,
        nameSimple: 'Al-Layl',
        nameArabic: 'الليل',
        nameComplex: 'Al-Layl',
        versesCount: 21,
        chapterNumber: 92,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Night',
      ),
      Chapter(
        id: 93,
        nameSimple: 'Ad-Duha',
        nameArabic: 'الضحى',
        nameComplex: 'Aḍ-Ḍuḥā',
        versesCount: 11,
        chapterNumber: 93,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Morning Hours',
      ),
      Chapter(
        id: 94,
        nameSimple: 'Ash-Sharh',
        nameArabic: 'الشرح',
        nameComplex: 'Ash-Sharḥ',
        versesCount: 8,
        chapterNumber: 94,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Opening',
      ),
      Chapter(
        id: 95,
        nameSimple: 'At-Tin',
        nameArabic: 'التين',
        nameComplex: 'At-Tīn',
        versesCount: 8,
        chapterNumber: 95,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Fig',
      ),
      Chapter(
        id: 96,
        nameSimple: 'Al-\'Alaq',
        nameArabic: 'العلق',
        nameComplex: 'Al-ʿAlaq',
        versesCount: 19,
        chapterNumber: 96,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Clot',
      ),
      Chapter(
        id: 97,
        nameSimple: 'Al-Qadr',
        nameArabic: 'القدر',
        nameComplex: 'Al-Qadr',
        versesCount: 5,
        chapterNumber: 97,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Night of Decree',
      ),
      Chapter(
        id: 98,
        nameSimple: 'Al-Bayyinah',
        nameArabic: 'البينة',
        nameComplex: 'Al-Bayyinah',
        versesCount: 8,
        chapterNumber: 98,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Clear Proof',
      ),
      Chapter(
        id: 99,
        nameSimple: 'Az-Zalzalah',
        nameArabic: 'الزلزلة',
        nameComplex: 'Az-Zalzalah',
        versesCount: 8,
        chapterNumber: 99,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Earthquake',
      ),
      Chapter(
        id: 100,
        nameSimple: 'Al-\'Adiyat',
        nameArabic: 'العاديات',
        nameComplex: 'Al-ʿĀdiyāt',
        versesCount: 11,
        chapterNumber: 100,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Chargers',
      ),
      Chapter(
        id: 101,
        nameSimple: 'Al-Qari\'ah',
        nameArabic: 'القارعة',
        nameComplex: 'Al-Qāriʿah',
        versesCount: 11,
        chapterNumber: 101,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Calamity',
      ),
      Chapter(
        id: 102,
        nameSimple: 'At-Takathur',
        nameArabic: 'التكاثر',
        nameComplex: 'At-Takāthur',
        versesCount: 8,
        chapterNumber: 102,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Competition',
      ),
      Chapter(
        id: 103,
        nameSimple: 'Al-\'Asr',
        nameArabic: 'العصر',
        nameComplex: 'Al-ʿAṣr',
        versesCount: 3,
        chapterNumber: 103,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Time',
      ),
      Chapter(
        id: 104,
        nameSimple: 'Al-Humazah',
        nameArabic: 'الهمزة',
        nameComplex: 'Al-Humazah',
        versesCount: 9,
        chapterNumber: 104,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Slanderer',
      ),
      Chapter(
        id: 105,
        nameSimple: 'Al-Fil',
        nameArabic: 'الفيل',
        nameComplex: 'Al-Fīl',
        versesCount: 5,
        chapterNumber: 105,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Elephant',
      ),
      Chapter(
        id: 106,
        nameSimple: 'Quraysh',
        nameArabic: 'قريش',
        nameComplex: 'Quraysh',
        versesCount: 4,
        chapterNumber: 106,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Quraysh',
      ),
      Chapter(
        id: 107,
        nameSimple: 'Al-Ma\'un',
        nameArabic: 'الماعون',
        nameComplex: 'Al-Māʿūn',
        versesCount: 7,
        chapterNumber: 107,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Assistance',
      ),
      Chapter(
        id: 108,
        nameSimple: 'Al-Kawthar',
        nameArabic: 'الكوثر',
        nameComplex: 'Al-Kawthar',
        versesCount: 3,
        chapterNumber: 108,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Abundance',
      ),
      Chapter(
        id: 109,
        nameSimple: 'Al-Kafirun',
        nameArabic: 'الكافرون',
        nameComplex: 'Al-Kāfirūn',
        versesCount: 6,
        chapterNumber: 109,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Disbelievers',
      ),
      Chapter(
        id: 110,
        nameSimple: 'An-Nasr',
        nameArabic: 'النصر',
        nameComplex: 'An-Naṣr',
        versesCount: 3,
        chapterNumber: 110,
        revelationPlace: 'Medinan',
        bismillahPre: true,
        description: 'The Victory',
      ),
      Chapter(
        id: 111,
        nameSimple: 'Al-Masad',
        nameArabic: 'المسد',
        nameComplex: 'Al-Masad',
        versesCount: 5,
        chapterNumber: 111,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Palm Fiber',
      ),
      Chapter(
        id: 112,
        nameSimple: 'Al-Ikhlas',
        nameArabic: 'الإخلاص',
        nameComplex: 'Al-Ikhlāṣ',
        versesCount: 4,
        chapterNumber: 112,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Sincerity',
      ),
      Chapter(
        id: 113,
        nameSimple: 'Al-Falaq',
        nameArabic: 'الفلق',
        nameComplex: 'Al-Falaq',
        versesCount: 5,
        chapterNumber: 113,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'The Dawn',
      ),
      Chapter(
        id: 114,
        nameSimple: 'An-Nas',
        nameArabic: 'الناس',
        nameComplex: 'An-Nās',
        versesCount: 6,
        chapterNumber: 114,
        revelationPlace: 'Meccan',
        bismillahPre: true,
        description: 'Mankind',
      ),
    ];
  }

  /// Sample verses for offline
  List<Verse> _getSampleVerses(int chapterId) {
    if (chapterId == 1) {
      return [
        Verse(
          id: 1,
          verseNumber: 1,
          chapterId: 1,
          textArabic: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
          textSimple: 'Bismillah hir Rahman nir Rahim',
          translation:
              'In the name of Allah, the Most Merciful, the Most Compassionate.',
          transliteration: '',
          audio: null,
          words: [],
        ),
        Verse(
          id: 2,
          verseNumber: 2,
          chapterId: 1,
          textArabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
          textSimple: 'Alhamdu lillahi Rabbil Alamin',
          translation: 'Praise be to Allah, Lord of the worlds.',
          transliteration: '',
          audio: null,
          words: [],
        ),
        Verse(
          id: 3,
          verseNumber: 3,
          chapterId: 1,
          textArabic: 'الرَّحْمَنِ الرَّحِيمِ',
          textSimple: 'Ar Rahman Ar Rahim',
          translation: 'The Most Merciful, the Most Compassionate.',
          transliteration: '',
          audio: null,
          words: [],
        ),
        Verse(
          id: 4,
          verseNumber: 4,
          chapterId: 1,
          textArabic: 'مَالِكِ يَوْمِ الدِّينِ',
          textSimple: 'Maliki yawmiddin',
          translation: 'Master of the Day of Judgment.',
          transliteration: '',
          audio: null,
          words: [],
        ),
        Verse(
          id: 5,
          verseNumber: 5,
          chapterId: 1,
          textArabic: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
          textSimple: 'Iyyaka nabudu wa iyyaka nastain',
          translation: 'It is You we worship and You we ask for help.',
          transliteration: '',
          audio: null,
          words: [],
        ),
        Verse(
          id: 6,
          verseNumber: 6,
          chapterId: 1,
          textArabic: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
          textSimple: 'Hdinas siratal mustaqim',
          translation: 'Guide us to the straight path.',
          transliteration: '',
          audio: null,
          words: [],
        ),
        Verse(
          id: 7,
          verseNumber: 7,
          chapterId: 1,
          textArabic:
              'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
          textSimple: 'Siratallazina an-amta alayhim',
          translation: 'The path of those upon whom You have bestowed favor.',
          transliteration: '',
          audio: null,
          words: [],
        ),
      ];
    }
    return List.generate(
      5,
      (index) => Verse(
        id: chapterId * 100 + index,
        verseNumber: index + 1,
        chapterId: chapterId,
        textArabic: 'Verse ${index + 1} of Chapter $chapterId',
        textSimple: 'Verse ${index + 1}',
        translation:
            'This is the English translation for verse ${index + 1} of chapter $chapterId.',
        transliteration: '',
        audio: null,
        words: [],
      ),
    );
  }
}

class VerseResponse {
  final List<Verse> verses;
  final PaginationInfo pagination;

  VerseResponse({required this.verses, required this.pagination});

  factory VerseResponse.fromJson(Map<String, dynamic> json) {
    final versesList = json['verses'] as List<dynamic>? ?? [];
    return VerseResponse(
      verses: versesList.map((v) => Verse.fromJson(v)).toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
    );
  }
}

class PaginationInfo {
  final int currentPage;
  final int nextPage;
  final int totalPages;
  final int totalCount;

  PaginationInfo({
    required this.currentPage,
    required this.nextPage,
    required this.totalPages,
    required this.totalCount,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'] ?? 1,
      nextPage: json['next_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      totalCount: json['total_count'] ?? 0,
    );
  }
}
