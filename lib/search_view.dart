import 'package:flutter/material.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/sura_view_deatils.dart';

import 'features/Koran/data/model/sura.dart';
import 'features/Koran/data/model/ayah.dart'; // Verse

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();

  List<Sura> _allSuras = [];
  List<Verse> _allVerses = [];

  List<Sura> _filteredSuras = [];
  List<Verse> _filteredVerses = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = await DBHelper.database;

    final suraMaps = await db.query('suras', orderBy: 'number ASC');
    _allSuras = suraMaps.map((e) => Sura.fromJson(e)).toList();

    final verseMaps = await db.query('verses', orderBy: 'id ASC');
    _allVerses = verseMaps.map((e) => Verse.fromJson(e)).toList();

    setState(() {
      _filteredSuras = List.from(_allSuras);
      _filteredVerses = List.from(_allVerses);
      _isLoading = false;
    });
  }

  String _normalizeArabic(String text) {
    if (text.isEmpty) return text;

    final diacriticsRegex = RegExp(r'[\u064B-\u0652\u0670]');
    String normalized = text.replaceAll(diacriticsRegex, '');

    normalized = normalized
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ٰ', 'ا');
    normalized = normalized.replaceAll('ى', 'ي');
    normalized = normalized.replaceAll('ئ', 'ي');
    normalized = normalized.replaceAll('ؤ', 'و');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll(' ', '');

    return normalized.trim();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredSuras = List.from(_allSuras);
        _filteredVerses = List.from(_allVerses);
      });
      return;
    }

    final normalizedQuery = _normalizeArabic(query);

    final suraResults = _allSuras.where((sura) {
      final nameNorm = _normalizeArabic(sura.name);
      return nameNorm.contains(normalizedQuery);
    }).toList();

    final verseResults = _allVerses.where((verse) {
      final textNorm = _normalizeArabic(verse.text);
      return textNorm.contains(normalizedQuery);
    }).toList();

    setState(() {
      _filteredSuras = suraResults;
      _filteredVerses = verseResults;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'السور'),
            Tab(text: 'الآيات'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب نص البحث هنا...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSurasTab(),
                      _buildVersesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurasTab() {
    if (_filteredSuras.isEmpty) {
      return const Center(child: Text('لا توجد سور مطابقة'));
    }

    return ListView.builder(
      itemCount: _filteredSuras.length,
      itemBuilder: (context, index) {
        final sura = _filteredSuras[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index.clamp(0, 10) * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - value)),
              child: child,
            ),
          ),
          child: ListTile(
            title: Text(
              sura.name,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'سورة رقم ${sura.number} - عدد الآيات ${sura.ayahs}',
              textDirection: TextDirection.rtl,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VerseListView(
                    suraNumber: sura.number,
                    SuraName: sura.name,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildVersesTab() {
    if (_filteredVerses.isEmpty) {
      return const Center(child: Text('لا توجد آيات مطابقة'));
    }

    return ListView.builder(
      itemCount: _filteredVerses.length,
      itemBuilder: (context, index) {
        final verse = _filteredVerses[index];

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index.clamp(0, 10) * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(
                verse.text,
                textDirection: TextDirection.rtl,
                style: const TextStyle( fontSize: 18),
              ),
              subtitle: Text(
                'سورة ${verse.sura} - آية ${verse.ayaNumber}',
                textDirection: TextDirection.rtl,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VerseListView(
                      suraNumber: verse.sura,
                      ayaNumber: verse.ayaNumber,
                      SuraName: verse.suraName ?? "سورة القران",
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
