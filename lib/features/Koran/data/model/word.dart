class Word {
  final String audio;
  final int aya;
  final int ayaID;
  final String charType;
  final String code;
  final String codeV3;
  final int id;
  final String simple;
  final int sura;
  final String text;
  final String translation;

  Word({
    required this.audio,
    required this.aya,
    required this.ayaID,
    required this.charType,
    required this.code,
    required this.codeV3,
    required this.id,
    required this.simple,
    required this.sura,
    required this.text,
    required this.translation,
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    audio: json['audio'] ?? '',
    aya: json['aya'] ?? 0,
    ayaID: json['ayaID'] ?? 0,
    charType: json['char_type'] ?? '',
    code: json['code'] ?? '',
    codeV3: json['code_v3'] ?? '',
    id: json['id'] ?? 0,
    simple: json['simple'] ?? '',
    sura: json['sura'] ?? 0,
    text: json['text'] ?? '',
    translation: json['translation'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'audio': audio,
    'aya': aya,
    'ayaID': ayaID,
    'char_type': charType,
    'code': code,
    'code_v3': codeV3,
    'id': id,
    'simple': simple,
    'sura': sura,
    'text': text,
    'translation': translation,
  };
}