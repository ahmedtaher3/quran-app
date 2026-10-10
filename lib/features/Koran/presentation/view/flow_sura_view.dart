import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/core/constants/app_constants.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/tafsir/tafsir_sheet.dart';

const _teal = Color(0xFF00695C);
const _arDigits = '٠١٢٣٤٥٦٧٨٩';
String _ar(int n) => '$n'.split('').map((d) => _arDigits[int.parse(d)]).join();

class FlowWord {
  final int id, ayahId, aya, page;
  final String text, audio, english;
  final String arabic; // Arabic meaning; often shared by a short phrase
  final String? source; // tafsir the meaning was checked against
  bool get hasMeaning => arabic.isNotEmpty;
  FlowWord(Map<String, Object?> r)
      : id = r['id'] as int,
        ayahId = r['ayaID'] as int,
        aya = r['ayaNumber'] as int,
        page = r['page'] as int,
        text = r['text'] as String? ?? '',
        audio = r['audio'] as String? ?? '',
        english = r['translation'] as String? ?? '',
        arabic = ((r['meaning_src'] != null ? r['meaning'] : r['code_v3'])
                    as String? ??
                '')
            .trim(),
        source = r['meaning_src'] as String?;
}

/// Continuous mushaf-style reading: one justified paragraph per mushaf
/// page, so lines reflow to the screen width. Tap a word to hear it and
/// see its meaning.
class FlowSuraView extends StatefulWidget {
  final int sura;
  final String suraName;
  final Widget? modeToggle;
  const FlowSuraView(
      {super.key, required this.sura, required this.suraName, this.modeToggle});

  @override
  State<FlowSuraView> createState() => _FlowSuraViewState();
}

class _FlowSuraViewState extends State<FlowSuraView> {
  List<List<FlowWord>>? _pages;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final words = (await DBHelper.getFlowWords(widget.sura)).map(FlowWord.new);
    final pages = <List<FlowWord>>[];
    for (final w in words) {
      if (pages.isEmpty || pages.last.first.page != w.page) pages.add([]);
      pages.last.add(w);
    }
    if (mounted) setState(() => _pages = pages);
  }

  void _zoom(double d) {
    final s = AppSettings.instance;
    s.update(quranSize: (s.quranSize + d).clamp(18, 44).toDouble());
  }

  Future<void> _onWord(FlowWord w) async {
    setState(() => _selected = w.id);
    if (w.audio.isNotEmpty) {
      QuranPlayer.instance
          .playClip('${AppConstants.wordAudioBaseUrl}${w.audio}', title: w.text);
    }
    await showModalBottomSheet(
      context: context,
      // size to content; long meanings scroll instead of overflowing
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _WordSheet(word: w, suraName: widget.suraName, parent: context),
    );
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final hasBasmala = widget.sura != 1 && widget.sura != 9;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.suraName,
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "تصغير الخط",
            icon: const Icon(Icons.text_decrease_rounded, color: Colors.white),
            onPressed: () => _zoom(-2),
          ),
          IconButton(
            tooltip: "تكبير الخط",
            icon: const Icon(Icons.text_increase_rounded, color: Colors.white),
            onPressed: () => _zoom(2),
          ),
          if (widget.modeToggle != null) widget.modeToggle!,
        ],
      ),
      body: pages == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: pages.length + (hasBasmala ? 1 : 0),
              itemBuilder: (context, i) {
                if (hasBasmala && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: AppSettings.instance
                          .quranStyle(scale: 1.05, color: AppColors.heading),
                    ),
                  );
                }
                final page = pages[i - (hasBasmala ? 1 : 0)];
                return _PageParagraph(
                  words: page,
                  selected: _selected,
                  onWord: _onWord,
                );
              },
            ),
    );
  }
}

class _PageParagraph extends StatefulWidget {
  final List<FlowWord> words;
  final int? selected;
  final void Function(FlowWord) onWord;
  const _PageParagraph(
      {required this.words, required this.selected, required this.onWord});

  @override
  State<_PageParagraph> createState() => _PageParagraphState();
}

class _PageParagraphState extends State<_PageParagraph> {
  // one recognizer per word, owned here so they're disposed with the page
  late final _taps = [
    for (final w in widget.words)
      TapGestureRecognizer()..onTap = () => widget.onWord(w)
  ];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.words;
    final marker = TextStyle(
        color: AppSettings.instance.isDark
            ? Colors.teal.shade200
            : Colors.teal.shade700);
    final meaningStyle = TextStyle(
        color: AppSettings.instance.isDark
            ? const Color(0xFFFFCA6B)
            : const Color(0xFFB45309));
    final spans = <InlineSpan>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final sel = w.id == widget.selected;
      spans.add(TextSpan(
        text: w.text,
        recognizer: _taps[i],
        style: sel
            ? TextStyle(
                color: _teal,
                backgroundColor: const Color(0x55FFB300),
              )
            : w.hasMeaning
                ? meaningStyle
                : null,
      ));
      final ayahEnds = i + 1 == words.length || words[i + 1].ayahId != w.ayahId;
      spans.add(ayahEnds
          ? TextSpan(text: ' ﴿${_ar(w.aya)}﴾ ', style: marker)
          : const TextSpan(text: ' '));
    }
    return Column(
      children: [
        Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: AppSettings.instance.quranStyle(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.teal.shade100)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_ar(words.first.page),
                    style: TextStyle(color: AppColors.subtle, fontSize: 13)),
              ),
              Expanded(child: Divider(color: Colors.teal.shade100)),
            ],
          ),
        ),
      ],
    );
  }
}

const _sourceNames = {
  'muyassar': 'التفسير الميسر',
  'mukhtasar': 'المختصر في تفسير القرآن',
  'saadi': 'تفسير السعدي',
};

Widget _meaningBox(String label, String text,
    {required bool rtl, required bool big}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: big ? AppColors.amberSoft : AppColors.tealSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(label, style: TextStyle(color: AppColors.subtle, fontSize: 13)),
        const SizedBox(height: 6),
        Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: big ? 20 : 15,
                  height: 1.6,
                  color: AppColors.text,
                  fontFamily: rtl ? null : 'Roboto')),
        ),
      ],
    ),
  );
}

class _WordSheet extends StatelessWidget {
  final FlowWord word;
  final String suraName;
  final BuildContext parent; // the sheet's own context dies on pop
  const _WordSheet(
      {required this.word, required this.suraName, required this.parent});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(word.text,
                style: AppSettings.instance
                    .quranStyle(scale: 1.4, color: AppColors.heading)),
            Text("$suraName • آية ${_ar(word.aya)}",
                style: TextStyle(color: AppColors.subtle)),
            const SizedBox(height: 16),
            if (word.hasMeaning)
              _meaningBox("المعنى", word.arabic, rtl: true, big: true),
            if (word.hasMeaning && word.source != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text("المصدر: ${_sourceNames[word.source] ?? word.source}",
                    style: TextStyle(color: AppColors.subtle, fontSize: 12)),
              ),
            if (word.english.isNotEmpty) ...[
              const SizedBox(height: 8),
              _meaningBox("الترجمة", word.english, rtl: false, big: false),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => QuranPlayer.instance.playClip(
                        '${AppConstants.wordAudioBaseUrl}${word.audio}',
                        title: word.text),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text("إعادة النطق"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final v = await DBHelper.getVerseById(word.ayahId);
                      if (v == null || !context.mounted) return;
                      Navigator.pop(context);
                      if (parent.mounted) showTafsirSheet(parent, v);
                    },
                    icon: const Icon(Icons.auto_stories_rounded),
                    label: const Text("تفسير الآية"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
