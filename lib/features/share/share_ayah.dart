import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';

class _Style {
  final String name;
  final List<Color> bg;
  final Color text, accent;
  final String? image;
  const _Style(this.name, this.bg, this.text, this.accent, {this.image});
}

const _styles = [
  _Style("زمردي", [Color(0xFF004D40), Color(0xFF00897B)], Colors.white,
      Color(0xFFFFD54F)),
  _Style("ليلي", [Color(0xFF0D1B2A), Color(0xFF1B263B)], Color(0xFFE0E1DD),
      Color(0xFFFFB300)),
  _Style("ورقي", [Color(0xFFF6EBD5), Color(0xFFEAD9B5)], Color(0xFF3B2E1E),
      Color(0xFF8D6E63)),
  _Style("زخرفة", [Color(0xFF004D40), Color(0xFF00695C)], Colors.white,
      Color(0xFFFFD54F),
      image: 'assets/image/pattern.jpg'),
];

void showShareAyah(BuildContext context, Verse verse, {String? suraName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ShareSheet(verse: verse, suraName: suraName),
  );
}

class _ShareSheet extends StatefulWidget {
  final Verse verse;
  final String? suraName;
  const _ShareSheet({required this.verse, this.suraName});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _key = GlobalKey();
  int _style = 0;
  bool _busy = false;

  String get _ref =>
      "${widget.verse.suraName ?? widget.suraName ?? 'سورة ${widget.verse.sura}'} • آية ${widget.verse.ayaNumber}";

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/ayah_${widget.verse.sura}_${widget.verse.ayaNumber}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: _ref,
        sharePositionOrigin: _origin(), // required on iPad
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    await SharePlus.instance.share(ShareParams(
      text: "﴿${widget.verse.text}﴾\n[$_ref]",
      sharePositionOrigin: _origin(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = _styles[_style];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          RepaintBoundary(
            key: _key,
            child: AspectRatio(
              aspectRatio: 4 / 5, // feed-friendly
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: s.bg,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  image: s.image == null
                      ? null
                      : DecorationImage(
                          image: AssetImage(s.image!),
                          fit: BoxFit.cover,
                          opacity: 0.22, // faint pattern over the gradient
                        ),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, color: s.accent, size: 22),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              "﴿${widget.verse.text}﴾",
                              textAlign: TextAlign.center,
                              style: AppSettings.instance
                                  .quranStyle(color: s.text)
                                  .copyWith(fontSize: 26),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(width: 60, height: 1.5, color: s.accent),
                    const SizedBox(height: 10),
                    Text(_ref,
                        style: TextStyle(
                            color: s.text.withOpacity(0.85), fontSize: 15)),
                    const SizedBox(height: 4),
                    Text("طريق القرآن",
                        style: TextStyle(color: s.accent, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _styles.length; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      avatar: CircleAvatar(
                          backgroundColor: _styles[i].bg.last, radius: 8),
                      label: Text(_styles[i].name),
                      selected: _style == i,
                      onSelected: (_) => setState(() => _style = i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareText,
                  icon: const Icon(Icons.text_fields_rounded),
                  label: const Text("نص"),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _shareImage,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded),
                  label: const Text("مشاركة كصورة"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
