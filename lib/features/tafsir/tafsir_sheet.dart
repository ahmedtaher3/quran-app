import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/tafsir/tafsir_source.dart';

const _teal = Color(0xFF00695C);

void showTafsirSheet(BuildContext context, Verse verse) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => _TafsirSheet(verse: verse, scroll: scroll),
    ),
  );
}

class _TafsirSheet extends StatefulWidget {
  final Verse verse;
  final ScrollController scroll;
  const _TafsirSheet({required this.verse, required this.scroll});

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  int? _source;
  Future<String>? _text;
  double _fontSize = 18;

  @override
  void initState() {
    super.initState();
    TafsirRepo.preferred().then(_select);
  }

  void _select(int id) {
    final v = widget.verse;
    setState(() {
      _source = id;
      _text = id == 0
          ? Future.value(v.tafsir ?? "لا يوجد تفسير متاح حالياً")
          : TafsirRepo.get(id, v.sura, v.ayaNumber ?? 0);
    });
    TafsirRepo.setPreferred(id);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.verse;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            v.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, height: 2.0),
          ),
          Text(
            [if (v.suraName != null) v.suraName!, "آية ${v.ayaNumber}"]
                .join(" • "),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in tafsirSources)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(s.name),
                      selected: _source == s.id,
                      onSelected: (_) => _select(s.id),
                      selectedColor: Colors.teal.shade100,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("تفسير ${_nameOf(_source)}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: _teal)),
              const Spacer(),
              IconButton(
                tooltip: "تصغير الخط",
                icon: const Icon(Icons.text_decrease_rounded),
                onPressed: () =>
                    setState(() => _fontSize = (_fontSize - 2).clamp(14, 30)),
              ),
              IconButton(
                tooltip: "تكبير الخط",
                icon: const Icon(Icons.text_increase_rounded),
                onPressed: () =>
                    setState(() => _fontSize = (_fontSize + 2).clamp(14, 30)),
              ),
            ],
          ),
          FutureBuilder<String>(
            future: _text,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text(
                        "تعذّر تحميل التفسير، تحقق من الاتصال بالإنترنت",
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => _select(_source!),
                        child: const Text("إعادة المحاولة"),
                      ),
                    ],
                  ),
                );
              }
              final text = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    text,
                    textAlign: TextAlign.justify,
                    style: TextStyle(fontSize: _fontSize, height: 1.9),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text("نسخ"),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text:
                                "${v.text}\n\nتفسير ${_nameOf(_source)}:\n$text"));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("تم النسخ")),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _nameOf(int? id) => tafsirSources
      .firstWhere((s) => s.id == id, orElse: () => tafsirSources.first)
      .name;
}
