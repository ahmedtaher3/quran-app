import 'package:flutter/material.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';

const bookmarkColors = <int>[
  0xFF00897B, // teal
  0xFFFFB300, // amber
  0xFFE53935, // red
  0xFF1E88E5, // blue
  0xFF8E24AA, // purple
];

class BookmarkResult {
  final int? color; // null => remove
  final String? note;
  BookmarkResult(this.color, this.note);
}

Future<BookmarkResult?> showBookmarkSheet(
    BuildContext context, Bookmark? existing) {
  return showModalBottomSheet<BookmarkResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookmarkSheet(existing: existing),
  );
}

class _BookmarkSheet extends StatefulWidget {
  final Bookmark? existing;
  const _BookmarkSheet({this.existing});

  @override
  State<_BookmarkSheet> createState() => _BookmarkSheetState();
}

class _BookmarkSheetState extends State<_BookmarkSheet> {
  late int _color = widget.existing?.color ?? bookmarkColors.first;
  late final _note = TextEditingController(text: widget.existing?.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.existing == null ? "إضافة علامة" : "تعديل العلامة",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00695C),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final c in bookmarkColors)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? Colors.black54
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _color == c
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _note,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: "ملاحظة (اختياري)",
                  filled: true,
                  fillColor: Colors.teal.shade50.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.existing != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(context, BookmarkResult(null, null)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("حذف"),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                          context, BookmarkResult(_color, _note.text)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("حفظ",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
