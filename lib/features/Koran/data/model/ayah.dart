class Verse {
  final int id;
  final int sura;
  final String? suraName;
  final int? ayaNumber;
  final int page;
  final int manzil;
  final int ruku;
  final int sajda;
  final int hizbQuarter;
  final String text;
  final String audio;
  final String? audioPath;
  String? tafsir;

  Verse({
    required this.id,
    required this.sura,
    this.suraName,
    this.ayaNumber,
    required this.page,
    required this.manzil,
    required this.ruku,
    required this.sajda,
    required this.hizbQuarter,
    required this.text,
    required this.audio,
    this.audioPath,
    this.tafsir,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      id: json['id'] ?? 0,
      sura: json['sura'] ?? 0,
      suraName: json['suraName'],
      ayaNumber: json['ayaNumber'] ?? 0,
      page: json['page'] ?? 0,
      manzil: json['manzil'] ?? 0,
      ruku: json['ruku'] ?? 0,
      sajda: json['sajda'] ?? 0,
      hizbQuarter: json['hizbQuarter'] ?? 0,
      text: json['text'] ?? "",
      audio: json['audio'] ?? "",
      audioPath: json['audioPath'],
      tafsir: json['tafsir'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sura': sura,
      'ayaNumber': ayaNumber,
      'page': page,
      'manzil': manzil,
      'ruku': ruku,
      'sajda': sajda,
      'hizbQuarter': hizbQuarter,
      'text': text,
      'audio': audio,
      'audioPath': audioPath,
      'tafsir': tafsir,
    };
  }
}
