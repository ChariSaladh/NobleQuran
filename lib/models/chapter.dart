/// Model representing a chapter (Surah) of the Quran
class Chapter {
  final int id;
  final String nameSimple;
  final String nameArabic;
  final String nameComplex;
  final int versesCount;
  final int chapterNumber;
  final String revelationPlace;
  final bool bismillahPre;
  final String description;

  Chapter({
    required this.id,
    required this.nameSimple,
    required this.nameArabic,
    required this.nameComplex,
    required this.versesCount,
    required this.chapterNumber,
    required this.revelationPlace,
    required this.bismillahPre,
    required this.description,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? 0,
      nameSimple: json['name_simple'] ?? '',
      nameArabic: json['name_arabic'] ?? '',
      nameComplex: json['name_complex'] ?? '',
      versesCount: json['verses_count'] ?? 0,
      chapterNumber: json['chapter_number'] ?? 0,
      revelationPlace: json['revelation_place'] ?? '',
      bismillahPre: json['bismillah_pre'] ?? true,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_simple': nameSimple,
      'name_arabic': nameArabic,
      'name_complex': nameComplex,
      'verses_count': versesCount,
      'chapter_number': chapterNumber,
      'revelation_place': revelationPlace,
      'bismillah_pre': bismillahPre,
      'description': description,
    };
  }
}
