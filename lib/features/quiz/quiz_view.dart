import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/quiz/quiz.dart';

const _teal = Color(0xFF00695C);

class QuizView extends StatefulWidget {
  const QuizView({super.key});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  List<Sura> _suras = [];
  bool _hasMemorized = false;
  int _best = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final suras = await DBHelper.getSuras();
    final mem = await DBHelper.getVersesWithNames(memorizedOnly: true);
    final best = (await SharedPreferences.getInstance()).getInt('quiz_best') ?? 0;
    if (mounted) {
      setState(() {
        _suras = suras;
        _hasMemorized = mem.length >= 8;
        _best = best;
      });
    }
  }

  Future<void> _start(Future<List<Verse>> poolF, String title) async {
    final qs = buildQuiz(await poolF);
    if (!mounted) return;
    if (qs.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("لا توجد آيات كافية لاختبار، اختر نطاقًا أكبر")));
      return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => _QuizRound(title: title, qs: qs)));
    _load();
  }

  Future<void> _pickSura() async {
    final s = await showModalBottomSheet<Sura>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, c) => ListView(
          controller: c,
          children: [
            for (final s in _suras.where((s) => s.ayahs >= 6))
              ListTile(
                leading: Text("${s.number}"),
                title: Text(s.name),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (s != null) {
      _start(DBHelper.getVersesWithNames(suras: [s.number]), s.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("اختبر حفظك",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.quiz_rounded, size: 72, color: Colors.teal.shade200),
          const SizedBox(height: 8),
          const Text(
            "10 أسئلة: أكمل الآية، الآية التالية، ومن أي سورة",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          if (_best > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("أفضل نتيجة: $_best من 10",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFA000))),
            ),
          const SizedBox(height: 24),
          if (_hasMemorized)
            _option(Icons.psychology_rounded, "من محفوظاتي",
                "أسئلة من الآيات التي تحفظها",
                () => _start(
                    DBHelper.getVersesWithNames(memorizedOnly: true), "محفوظاتي")),
          _option(Icons.menu_book_rounded, "سورة محددة", "اختر سورة واختبر نفسك",
              _pickSura),
          _option(Icons.auto_awesome_rounded, "جزء عمّ", "السور من النبأ إلى الناس",
              () => _start(
                  DBHelper.getVersesWithNames(
                      suras: [for (var i = 78; i <= 114; i++) i]),
                  "جزء عمّ")),
          _option(Icons.public_rounded, "القرآن كاملًا", "تحدٍّ من كل المصحف",
              () => _start(DBHelper.getVersesWithNames(), "القرآن كاملًا")),
        ],
      ),
    );
  }

  Widget _option(IconData icon, String title, String sub, VoidCallback onTap) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: Icon(icon, color: _teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _QuizRound extends StatefulWidget {
  final String title;
  final List<Question> qs;
  const _QuizRound({required this.title, required this.qs});

  @override
  State<_QuizRound> createState() => _QuizRoundState();
}

class _QuizRoundState extends State<_QuizRound> {
  int _i = 0;
  int? _picked;
  int _score = 0;

  static const _titles = {
    QuizType.complete: "أكمل الآية",
    QuizType.next: "ما الآية التالية؟",
    QuizType.whichSura: "من أي سورة هذه الآية؟",
  };

  void _pick(int i) {
    if (_picked != null) return;
    setState(() {
      _picked = i;
      if (i == widget.qs[_i].answer) _score++;
    });
  }

  Future<void> _next() async {
    if (_i + 1 < widget.qs.length) {
      setState(() {
        _i++;
        _picked = null;
      });
      return;
    }
    final p = await SharedPreferences.getInstance();
    final total = widget.qs.length;
    final normalized = (_score * 10 / total).round();
    if (normalized > (p.getInt('quiz_best') ?? 0)) {
      await p.setInt('quiz_best', normalized);
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(_score == total ? "ممتاز! 🌟" : "انتهى الاختبار",
            textAlign: TextAlign.center),
        content: Text("نتيجتك: $_score من $total",
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("تم")),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.qs[_i];
    final isText = q.type != QuizType.whichSura;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("${widget.title} • ${_i + 1} من ${widget.qs.length}",
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _i / widget.qs.length,
            backgroundColor: Colors.white24,
            color: const Color(0xFFFFB300),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_titles[q.type]!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.shade100, width: 2),
              ),
              child: Text(q.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, height: 1.9)),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < q.options.length; i++) _optionTile(q, i, isText),
            if (_picked != null) ...[
              const SizedBox(height: 8),
              if (q.type != QuizType.whichSura)
                Text("${q.verse.suraName ?? ''} • آية ${q.verse.ayaNumber}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                    _i + 1 < widget.qs.length ? "السؤال التالي" : "النتيجة"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _optionTile(Question q, int i, bool isText) {
    Color border = Colors.grey.shade300;
    Color? fill;
    IconData? icon;
    if (_picked != null) {
      if (i == q.answer) {
        border = Colors.green;
        fill = Colors.green.shade50;
        icon = Icons.check_circle_rounded;
      } else if (i == _picked) {
        border = Colors.red;
        fill = Colors.red.shade50;
        icon = Icons.cancel_rounded;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => _pick(i),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: fill ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  q.options[i],
                  maxLines: isText ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isText ? 18 : 17, height: 1.8),
                ),
              ),
              if (icon != null) Icon(icon, color: border),
            ],
          ),
        ),
      ),
    );
  }
}
