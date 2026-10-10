class Tafsir {
  final int id;
  final int sura;
  final int aya;
  final String text;

  Tafsir({
    required this.id,
    required this.sura,
    required this.aya,
    required this.text,
  });

  factory Tafsir.fromJson(Map<String, dynamic> json) => Tafsir(
    id: int.parse(json['id']),
    sura: int.parse(json['sura']),
    aya: int.parse(json['aya']),
    text: json['translation'] ?? "",
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'sura': sura,
    'aya': aya,
    'text': text,
  };
}