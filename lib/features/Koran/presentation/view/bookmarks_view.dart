import 'package:flutter/material.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/bookmark_sheet.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/sura_view_deatils.dart';

class BookmarksView extends StatefulWidget {
  const BookmarksView({super.key});

  @override
  State<BookmarksView> createState() => _BookmarksViewState();
}

class _BookmarksViewState extends State<BookmarksView> {
  List<Bookmark>? _items;
  int? _filterColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DBHelper.getBookmarks();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _open(Bookmark b) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerseListView(
          suraNumber: b.sura,
          SuraName: b.suraName ?? "",
          ayaNumber: b.aya,
        ),
      ),
    );
    _load(); // bookmarks may have been edited inside the sura
  }

  @override
  Widget build(BuildContext context) {
    final items = _items
        ?.where((b) => _filterColor == null || b.color == _filterColor)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("العلامات",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF00695C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    children: [
                      _chip(null),
                      for (final c in bookmarkColors) _chip(c),
                    ],
                  ),
                ),
                Expanded(
                  child: items!.isEmpty
                      ? _empty()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _tile(items[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _chip(int? color) {
    final selected = _filterColor == color;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _filterColor = color),
        label: color == null
            ? const Text("الكل")
            : Container(
                width: 16,
                height: 16,
                decoration:
                    BoxDecoration(color: Color(color), shape: BoxShape.circle),
              ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_rounded,
              size: 72, color: Colors.teal.shade100),
          const SizedBox(height: 12),
          Text("لا توجد علامات بعد",
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text("اضغط على أيقونة العلامة بجوار أي آية",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _tile(Bookmark b) {
    final c = Color(b.color);
    return Dismissible(
      key: ValueKey(b.verseId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await DBHelper.deleteBookmark(b.verseId);
        setState(() => _items!.remove(b));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(b),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark_rounded, color: c, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      "${b.suraName ?? ''} • آية ${b.aya}",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  b.text ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, height: 1.8),
                ),
                if (b.note != null) ...[
                  const SizedBox(height: 8),
                  Text(b.note!,
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
