import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/words_dialog.dart';
import 'AudioManager.dart';
import 'features/Koran/data/model/ayah.dart';
import 'core/constants/app_constants.dart';

class VerseListScreen extends StatefulWidget {
  const VerseListScreen({
    super.key,
    required this.suraNumber,
  });

  final int suraNumber;

  @override
  _VerseListScreenState createState() => _VerseListScreenState(suraNumber);
}

class _VerseListScreenState extends State<VerseListScreen> {
  late Future<List<Verse>> _verses;

  _VerseListScreenState(this.suraNumber);

  int suraNumber;

  @override
  void initState() {
    super.initState();
    _verses = DBHelper.getVersesBySura(suraNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verses')),
      body: FutureBuilder<List<Verse>>(
        future: _verses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return Center(child: Text('No verses found'));

          final verses = snapshot.data!;
          return ListView.builder(
            itemCount: verses.length,
            itemBuilder: (context, index) {
              final verse = verses[index];

              return InkWell(
                onTap: () async {
                  final words = await DBHelper.getWordsByAyah(verse.id);

                  showDialog(
                    context: context,
                    builder: (context) => WordsDialog(words: words),
                  );
                },
                child: Card(
                  margin: EdgeInsets.all(12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verse.text,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.notes),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  builder: (context) {
                                    return Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(16, 16, 16, 32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "تفسير الآية",
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.5,
                                            child: SingleChildScrollView(
                                              child: Text(
                                                verse.tafsir ??
                                                    "لا يوجد تفسير متاح",
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  height: 1.6,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.play_arrow),
                              onPressed: () async {
                                final url =
                                    "${AppConstants.verseAudioBaseUrl}${verse.audio}";
                                await AudioManager.playAyah(url);
/*
                                AudioManager.setOnStateChanged((state) {
                                  print("⏳  Loading...");
                                  if (state == PlayerState.playing) {
                                    print("▶️ Playing...");
                                  }
                                });*/
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TagsList extends StatelessWidget {
  final List<String> tags;

  const TagsList({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tag,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
    );
  }
}
