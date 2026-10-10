import 'dart:async';

import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/sura_view_deatils.dart';
import 'package:untitled/features/recite/matcher.dart' show normalizeArabic;
import 'package:untitled/features/search/search_index.dart';

const _teal = Color(0xFF00695C);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // built once per app run; normalizing 6236 ayat per keystroke was the old cost
  static List<IndexedAyah>? _index;
  static List<Sura> _suras = [];

  final _controller = TextEditingController();
  Timer? _debounce;

  SearchScope _scope = SearchScope.text;
  int? _sura, _juz;
  List<SearchHit> _hits = [];
  List<Sura> _suraHits = [];
  bool _loading = _index == null;

  @override
  void initState() {
    super.initState();
    if (_index == null) _build();
  }

  Future<void> _build() async {
    final db = await DBHelper.database;
    _suras = (await db.query('suras', orderBy: 'number'))
        .map(Sura.fromJson)
        .toList();
    final rows = await db.query('verses',
        columns: ['id', 'sura', 'ayaNumber', 'hizbQuarter', 'text', 'tafsir'],
        orderBy: 'id');
    _index = [
      for (final r in rows)
        IndexedAyah(
          r['id'] as int,
          r['sura'] as int,
          r['ayaNumber'] as int,
          ((r['hizbQuarter'] as int) - 1) ~/ 8 + 1,
          r['text'] as String,
          r['tafsir'] as String?,
        )
    ];
    if (mounted) setState(() => _loading = false);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _run);
  }

  void _run() {
    final q = _controller.text.trim();
    if (_index == null) return;
    final nq = normalizeArabic(q);
    setState(() {
      _hits = search(_index!, q, scope: _scope, sura: _sura, juz: _juz);
      _suraHits = nq.isEmpty
          ? []
          : _suras
              .where((s) =>
                  normalizeArabic(s.name).contains(nq) || '${s.number}' == q)
              .toList();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _suraName(int n) =>
      _suras.firstWhere((s) => s.number == n, orElse: () => _suras.first).name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: "ابحث بكلمة أو جزء من آية…",
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _run();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _filters(),
                Expanded(child: _results()),
              ],
            ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          ChoiceChip(
            label: const Text("نص الآيات"),
            selected: _scope == SearchScope.text,
            onSelected: (_) {
              _scope = SearchScope.text;
              _run();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text("بالموضوع (التفسير)"),
            selected: _scope == SearchScope.tafsir,
            onSelected: (_) {
              _scope = SearchScope.tafsir;
              _run();
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.menu_book_rounded, size: 18),
            label: Text(_sura == null ? "كل السور" : _suraName(_sura!)),
            onPressed: _pickSura,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.layers_rounded, size: 18),
            label: Text(_juz == null ? "كل الأجزاء" : "الجزء $_juz"),
            onPressed: _pickJuz,
          ),
        ],
      ),
    );
  }

  Future<void> _pickSura() async {
    final v = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, c) => ListView(
          controller: c,
          children: [
            ListTile(
                title: const Text("كل السور"),
                onTap: () => Navigator.pop(context, 0)),
            for (final s in _suras)
              ListTile(
                leading: Text("${s.number}"),
                title: Text(s.name),
                onTap: () => Navigator.pop(context, s.number),
              ),
          ],
        ),
      ),
    );
    if (v == null) return;
    _sura = v == 0 ? null : v;
    _run();
  }

  Future<void> _pickJuz() async {
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            for (var j = 0; j <= 30; j++)
              InkWell(
                onTap: () => Navigator.pop(context, j),
                child: Center(
                  child: Text(j == 0 ? "الكل" : "$j",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (_juz ?? 0) == j ? _teal : Colors.black87)),
                ),
              ),
          ],
        ),
      ),
    );
    if (v == null) return;
    _juz = v == 0 ? null : v;
    _run();
  }

  Widget _results() {
    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            "ابحث بدون تشكيل، بأي ترتيب للكلمات، أو اختر «بالموضوع» للبحث في معاني الآيات",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.8),
          ),
        ),
      );
    }
    if (_hits.isEmpty && _suraHits.isEmpty) {
      return const Center(child: Text("لا توجد نتائج"));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_suraHits.isNotEmpty) ...[
          _header("السور"),
          for (final s in _suraHits)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.tealSoft,
                child: Text("${s.number}",
                    style: const TextStyle(color: _teal, fontSize: 13)),
              ),
              title: Text(s.name),
              subtitle: Text("${s.ayahs} آية"),
              onTap: () => _open(s.number, null),
            ),
        ],
        _header("${_hits.length} آية"),
        // ponytail: plain ListView children, capped at 300; switch to a
        // lazy builder if users need to page through every hit
        for (final h in _hits.take(300)) _hitTile(h),
        if (_hits.length > 300)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("تظهر أول 300 نتيجة، حدّد البحث أكثر",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
      ],
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(t,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.heading)),
      );

  Widget _hitTile(SearchHit h) {
    final a = h.ayah;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(a.sura, a.aya),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  for (var i = 0; i < a.words.length; i++) ...[
                    TextSpan(
                      text: a.words[i],
                      style: h.highlight.contains(i)
                          ? const TextStyle(
                              color: _teal,
                              backgroundColor: Color(0x33FFB300),
                              fontWeight: FontWeight.bold)
                          : null,
                    ),
                    const TextSpan(text: ' '),
                  ],
                ]),
                style: const TextStyle(fontSize: 19, height: 1.9),
              ),
              const SizedBox(height: 4),
              Text("${_suraName(a.sura)} • آية ${a.aya} • الجزء ${a.juz}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  void _open(int sura, int? aya) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerseListView(
          suraNumber: sura,
          ayaNumber: aya,
          SuraName: _suraName(sura),
        ),
      ),
    );
  }
}
