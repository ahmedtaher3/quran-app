import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/hifz/hifz_store.dart';
import 'package:untitled/features/hifz/srs.dart';

const _teal = Color(0xFF00695C);

class HifzView extends StatefulWidget {
  const HifzView({super.key});

  @override
  State<HifzView> createState() => _HifzViewState();
}

class _HifzViewState extends State<HifzView> {
  List<Sura> _suras = [];
  Map<int, ({int count, double strength})> _bySura = {};
  int _due = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final suras = await DBHelper.getSuras();
    final by = await HifzStore.bySura();
    final due = (await HifzStore.due()).length;
    if (!mounted) return;
    setState(() {
      _suras = suras;
      _bySura = by;
      _due = due;
      _loading = false;
    });
  }

  Future<void> _addSura() async {
    final picked = await showModalBottomSheet<(Sura, int, int)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddSheet(suras: _suras),
    );
    if (picked == null) return;
    final (sura, from, to) = picked;
    final verses = (await DBHelper.getVersesBySura(sura.number))
        .where((v) => (v.ayaNumber ?? 0) >= from && (v.ayaNumber ?? 0) <= to)
        .toList();
    final added = await HifzStore.add(verses);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("أُضيفت $added آية من ${sura.name} للمراجعة")));
    }
    _load();
  }

  Future<void> _startReview() async {
    final items = await HifzStore.due();
    if (!mounted || items.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewSession(items: items)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final memorized = _bySura.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("الحفظ والمراجعة",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addSura,
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("إضافة للحفظ"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _dueCard(),
                const SizedBox(height: 24),
                if (memorized.isEmpty)
                  _empty()
                else ...[
                  Text("محفوظاتي",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.heading)),
                  const SizedBox(height: 8),
                  for (final e in memorized) _suraTile(e.key, e.value),
                ],
              ],
            ),
    );
  }

  Widget _dueCard() {
    final has = _due > 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00897B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.psychology_rounded, color: Colors.white, size: 44),
          const SizedBox(height: 8),
          Text(
            has ? "$_due آية للمراجعة اليوم" : "لا توجد مراجعة مستحقة اليوم",
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            has
                ? "التكرار المتباعد يثبّت الحفظ بأقل جهد"
                : "أضف سورة أو مقطعًا لتبدأ الحفظ",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (has) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _teal,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("ابدأ المراجعة",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.menu_book_rounded,
                size: 64, color: Colors.teal.shade100),
            const SizedBox(height: 8),
            Text("لم تضف أي محفوظات بعد",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );

  Widget _suraTile(int number, ({int count, double strength}) info) {
    final sura = _suras.firstWhere((s) => s.number == number);
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(sura.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${info.count} من ${sura.ayahs} آية"),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: info.strength,
                minHeight: 6,
                backgroundColor: AppColors.tealSoft,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (_) async {
            await HifzStore.removeSura(number);
            _load();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'remove', child: Text("إزالة من المحفوظات")),
          ],
        ),
      ),
    );
  }
}

class _AddSheet extends StatefulWidget {
  final List<Sura> suras;
  const _AddSheet({required this.suras});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  Sura? _sura;
  RangeValues _range = const RangeValues(1, 1);
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.suras
        .where((s) => _q.isEmpty || s.name.contains(_q) || '${s.number}' == _q)
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, top: 12),
        child: SizedBox(
          // shrink with the keyboard so the sheet never climbs past the top
          height: (MediaQuery.of(context).size.height -
                  MediaQuery.of(context).viewInsets.bottom) *
              0.8,
          child: _sura == null ? _pickSura(list) : _pickRange(_sura!),
        ),
      ),
    );
  }

  Widget _pickSura(List<Sura> list) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: "ابحث عن سورة"),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final s in list)
                  ListTile(
                    leading: Text("${s.number}"),
                    title: Text(s.name),
                    subtitle: Text("${s.ayahs} آية"),
                    onTap: () => setState(() {
                      _sura = s;
                      _range = RangeValues(1, s.ayahs.toDouble());
                    }),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _pickRange(Sura s) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => setState(() => _sura = null),
                ),
                Text(s.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
                "من الآية ${_range.start.round()} إلى الآية ${_range.end.round()}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18)),
            if (s.ayahs > 1)
              RangeSlider(
                values: _range,
                min: 1,
                max: s.ayahs.toDouble(),
                divisions: s.ayahs - 1,
                onChanged: (v) => setState(() => _range = v),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                  context, (s, _range.start.round(), _range.end.round())),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                  "إضافة ${_range.end.round() - _range.start.round() + 1} آية"),
            ),
          ],
        ),
      );
}

class ReviewSession extends StatefulWidget {
  final List<(SrsCard, Verse)> items;
  const ReviewSession({super.key, required this.items});

  @override
  State<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<ReviewSession> {
  late final List<(SrsCard, Verse)> _queue = [...widget.items];
  int _i = 0;
  bool _revealed = false;
  bool _hint = false;
  Verse? _prev;
  int _again = 0;

  @override
  void initState() {
    super.initState();
    _loadPrev();
  }

  Future<void> _loadPrev() async {
    final v = _queue[_i].$2;
    final p = (v.ayaNumber ?? 1) > 1 ? await DBHelper.getVerseById(v.id - 1) : null;
    if (mounted) setState(() => _prev = p);
  }

  Future<void> _grade(Grade g) async {
    final (card, verse) = _queue[_i];
    await HifzStore.save(review(card, g, DateTime.now()));
    if (g == Grade.again) {
      _again++;
      _queue.add((card, verse)); // see it again this session
    }
    if (_i + 1 >= _queue.length) {
      if (mounted) _finish();
      return;
    }
    setState(() {
      _i++;
      _revealed = false;
      _hint = false;
      _prev = null;
    });
    _loadPrev();
  }

  void _finish() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("أحسنت! انتهت المراجعة", textAlign: TextAlign.center),
        content: Text(
          "راجعت ${widget.items.length} آية${_again > 0 ? '، وأعدت $_again منها' : ''}",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("تم"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verse = _queue[_i].$2;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("${_i + 1} من ${_queue.length}",
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _i / _queue.length,
            backgroundColor: Colors.white24,
            color: const Color(0xFFFFB300),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("${verse.suraName ?? ''} • آية ${verse.ayaNumber}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_prev != null)
                Text(
                  _prev!.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20, height: 1.9, color: Colors.grey.shade500),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.teal.shade100, width: 2),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: _revealed
                          ? Text(verse.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 26, height: 2))
                          : _hint
                              ? Text(openingHint(verse.text),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 26,
                                      height: 2,
                                      color: Colors.teal.shade700))
                              : Column(
                                  children: [
                                    Icon(Icons.visibility_off_rounded,
                                        size: 48, color: Colors.teal.shade100),
                                    const SizedBox(height: 8),
                                    Text(
                                      _prev == null
                                          ? "اقرأ الآية من حفظك"
                                          : "ما الآية التالية؟",
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_revealed)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _hint ? null : () => setState(() => _hint = true),
                        icon: const Icon(Icons.lightbulb_outline_rounded),
                        label: const Text("تلميح"),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _revealed = true),
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text("إظهار الآية"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                TextButton.icon(
                  onPressed: () => QuranPlayer.instance.play([verse]),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text("استمع للتصحيح"),
                ),
                Row(
                  children: [
                    _gradeBtn("نسيت", Grade.again, Colors.red.shade400),
                    _gradeBtn("صعب", Grade.hard, Colors.orange.shade600),
                    _gradeBtn("جيد", Grade.good, Colors.teal),
                    _gradeBtn("سهل", Grade.easy, Colors.green.shade600),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradeBtn(String label, Grade g, Color c) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            onPressed: () => _grade(g),
            style: ElevatedButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              padding: EdgeInsets.zero,
            ),
            child: Text(label),
          ),
        ),
      );
}
