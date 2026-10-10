import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/recite/matcher.dart';

const _teal = Color(0xFF00695C);

/// Pick a sura, then recite it from memory with live word checking.
class ReciteStartView extends StatelessWidget {
  const ReciteStartView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("التسميع بالصوت",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Sura>>(
        future: DBHelper.getSuras(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "اختر سورة واقرأها من حفظك، وستظهر الكلمات كلما قرأتها صحيحة",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                ),
              ),
              for (final s in snap.data!)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.tealSoft,
                    child: Text("${s.number}",
                        style: const TextStyle(color: _teal, fontSize: 13)),
                  ),
                  title: Text(s.name),
                  subtitle: Text("${s.ayahs} آية"),
                  trailing: const Icon(Icons.mic_rounded, color: _teal),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReciteView(sura: s)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Ayah {
  final Verse verse;
  final List<String> display; // uthmani words
  final List<String> expected; // normalized simple spellings
  _Ayah(this.verse, this.display, this.expected);
}

class ReciteView extends StatefulWidget {
  final Sura sura;
  const ReciteView({super.key, required this.sura});

  @override
  State<ReciteView> createState() => _ReciteViewState();
}

class _ReciteViewState extends State<ReciteView> {
  final _speech = SpeechToText();
  List<_Ayah> _ayat = [];
  int _i = 0;
  List<WordState> _states = [];
  // Recognition keeps running across ayat; restarting the engine per ayah
  // crashes the iOS plugin. _consumed marks where the current ayah starts.
  List<String> _heardBefore = []; // words from earlier engine sessions
  List<String> _heardNow = [];
  int _consumed = 0;
  bool _starting = false;
  List<String> get _heard => [..._heardBefore, ..._heardNow];
  String _partial = '';
  bool _ready = false, _listening = false, _active = false, _hideText = true;
  String? _error;
  String? _localeId;
  int _correctWords = 0, _totalWords = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final verses = await DBHelper.getVersesBySura(widget.sura.number);
    final ayat = <_Ayah>[];
    for (final v in verses) {
      final words = (await DBHelper.getWordsByAyah(v.id))
          .where((w) => w.charType == 'word');
      final display = words.map((w) => w.text).toList();
      final expected = words.map((w) => normalizeArabic(w.simple)).toList();
      ayat.add(display.isEmpty
          ? _Ayah(v, v.text.split(' '), tokens(v.text))
          : _Ayah(v, display, expected));
    }
    final ok = await _speech.initialize(
      onStatus: _onStatus,
      onError: (e) {
        // no-speech timeouts are normal pauses, not errors worth showing
        const silent = {'error_no_match', 'error_speech_timeout'};
        if (!mounted || silent.contains(e.errorMsg)) return;
        setState(
            () => _error = "تعذّر الاستماع، اضغط الميكروفون وحاول مرة أخرى");
      },
    );
    if (ok) {
      final locales = await _speech.locales();
      _localeId = locales
          .map((l) => l.localeId)
          .firstWhere((id) => id.startsWith('ar'), orElse: () => 'ar_SA');
    }
    if (!mounted) return;
    setState(() {
      _ayat = ayat;
      _states = List.filled(ayat.first.expected.length, WordState.pending);
      _ready = ok;
      if (!ok) _error = "التعرّف على الصوت غير متاح على هذا الجهاز";
    });
  }

  void _onStatus(String status) {
    final listening = status == 'listening';
    if (mounted) setState(() => _listening = listening);
    // engines stop after a pause; keep going while the user wants to recite
    if ((status == 'done' || status == 'notListening') && _active) {
      _heardBefore = [..._heardBefore, ..._heardNow];
      _heardNow = [];
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_active && mounted && !_speech.isListening) _listen();
      });
    }
  }

  Future<void> _listen() async {
    if (_starting || _speech.isListening) return;
    _starting = true;
    setState(() => _error = null);
    await QuranPlayer.instance.stop(); // shares the audio session
    try {
      await _speech.listen(
        onResult: (r) {
          _heardNow = tokens(r.recognizedWords);
          _partial = r.recognizedWords;
          _check();
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(minutes: 3),
        ),
      );
    } finally {
      _starting = false;
    }
  }

  void _check() {
    final a = _ayat[_i];
    final heard = _heard;
    final states = align(
        a.expected, heard.skip(_consumed.clamp(0, heard.length)).toList());
    setState(() => _states = states);
    if (states.isNotEmpty && states.last == WordState.correct) _advance();
  }

  void _advance() {
    _correctWords += _states.where((s) => s == WordState.correct).length;
    _totalWords += _states.length;
    if (_i + 1 >= _ayat.length) {
      _stop();
      _finish();
      return;
    }
    _consumed = _heard.length;
    _partial = '';
    setState(() {
      _i++;
      _states = List.filled(_ayat[_i].expected.length, WordState.pending);
    });
  }

  Future<void> _toggle() async {
    if (_active) {
      _stop();
    } else {
      _active = true;
      await _listen();
    }
  }

  void _stop() {
    _active = false;
    if (_speech.isListening) _speech.stop();
    setState(() => _listening = false);
  }

  void _finish() {
    final pct =
        _totalWords == 0 ? 0 : (_correctWords * 100 / _totalWords).round();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("أتممت التسميع", textAlign: TextAlign.center),
        content: Text("دقة التلاوة: $pct%",
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
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

  void _skip() {
    // count unrecited words as missed, then move on
    setState(() => _states = [
          for (final s in _states) s == WordState.pending ? WordState.missed : s
        ]);
    _advance();
  }

  @override
  void dispose() {
    _active = false;
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            Text(widget.sura.name, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _hideText ? "إظهار النص" : "إخفاء النص",
            icon: Icon(
                _hideText
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.white),
            onPressed: () => setState(() => _hideText = !_hideText),
          ),
        ],
        bottom: _ayat.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _i / _ayat.length,
                  backgroundColor: Colors.white24,
                  color: const Color(0xFFFFB300),
                ),
              ),
      ),
      body: _ayat.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        "الآية ${_ayat[_i].verse.ayaNumber} من ${_ayat.length}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.teal.shade800,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: _listening
                                  ? Colors.teal
                                  : Colors.teal.shade100,
                              width: 2),
                        ),
                        child: Center(
                          child: SingleChildScrollView(child: _words()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? (_partial.isEmpty ? " " : _partial),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _error != null
                              ? Colors.red
                              : Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _skip,
                          child: const Text("تخطي الآية"),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _ready ? _toggle : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: !_ready
                                  ? Colors.grey
                                  : _active
                                      ? Colors.red.shade400
                                      : _teal,
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (_listening)
                                  BoxShadow(
                                      color: Colors.red.withOpacity(0.35),
                                      blurRadius: 24,
                                      spreadRadius: 6),
                              ],
                            ),
                            child: Icon(
                                _active
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 40),
                          ),
                        ),
                        const SizedBox(width: 96), // balances the skip button
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _words() {
    final a = _ayat[_i];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 12,
      children: [
        for (var k = 0; k < a.display.length; k++)
          _word(a.display[k],
              k < _states.length ? _states[k] : WordState.pending),
      ],
    );
  }

  Widget _word(String text, WordState s) {
    final hidden = _hideText && s == WordState.pending;
    final color = switch (s) {
      WordState.correct => Colors.green.shade700,
      WordState.missed => Colors.red.shade600,
      WordState.pending => AppColors.text,
    };
    return hidden
        ? Container(
            width: 14.0 * text.length.clamp(2, 6),
            height: 28,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : Text(text, style: TextStyle(fontSize: 26, height: 1.8, color: color));
  }
}
