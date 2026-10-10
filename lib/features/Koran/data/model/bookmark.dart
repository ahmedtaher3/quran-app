class Bookmark {
  final int verseId;
  final int sura;
  final int aya;
  final int color;
  final String? note;
  final int createdAt;
  // filled by join, not stored
  final String? suraName;
  final String? text;

  Bookmark({
    required this.verseId,
    required this.sura,
    required this.aya,
    required this.color,
    this.note,
    required this.createdAt,
    this.suraName,
    this.text,
  });

  factory Bookmark.fromMap(Map<String, dynamic> m) => Bookmark(
        verseId: m['verse_id'],
        sura: m['sura'],
        aya: m['aya'],
        color: m['color'],
        note: m['note'],
        createdAt: m['created_at'],
        suraName: m['suraName'],
        text: m['text'],
      );

  Map<String, dynamic> toMap() => {
        'verse_id': verseId,
        'sura': sura,
        'aya': aya,
        'color': color,
        'note': note,
        'created_at': createdAt,
      };
}
