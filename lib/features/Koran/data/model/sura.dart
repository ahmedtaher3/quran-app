class Sura {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int ayahs;
  final String revelationType;

  Sura({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.ayahs,
    required this.revelationType,
  });

  factory Sura.fromJson(Map<String, dynamic> json) => Sura(
        number: json['number'],
        name: json['name'],
        englishName: json['englishName'],
        englishNameTranslation: json['englishNameTranslation'],
        ayahs: json['ayahs'],
        revelationType: json['revelationType'],
      );

  Map<String, dynamic> toMap() => {
        'number': number,
        'name': name,
        'englishName': englishName,
        'englishNameTranslation': englishNameTranslation,
        'ayahs': ayahs,
        'revelationType': revelationType,
      };

  @override
  String toString() {
    return '''
Sura(
  number: $number,
  name: $name,
  englishName: $englishName,
  englishNameTranslation: $englishNameTranslation,
  ayahs: $ayahs,
  revelationType: $revelationType
)''';
  }
}
