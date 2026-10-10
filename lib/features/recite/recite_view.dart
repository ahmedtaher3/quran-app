import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:untitled/core/constants/app_constants.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/recite/matcher.dart';

const _teal = Color(0xFF00695C);

/// Session settings chosen before reciting; the last choice is remembered.
class ReciteOptions {
  final int startAya;
  final bool help; // play the next word when the reciter gets stuck
  final int helpDelay; // seconds of no progress before helping
  final bool lenient; // tolerate unclear (e.g. children's) pronunciation
  const ReciteOptions(
      {this.startAya = 1,
      this.help = true,
      this.helpDelay = 5,
      this.lenient = false});

  static Future<ReciteOptions> load() async {
    final p = await SharedPreferences.getInstance();
    return ReciteOptions(
      help: p.getBool('recite_help') ?? true,
      helpDelay: p.getInt('recite_help_delay') ?? 5,
      lenient: p.getBool('recite_lenient') ?? false,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('recite_help', help);
    await p.setInt('recite_help_delay', helpDelay);
    await p.setBool('recite_lenient', lenient);
  }
}

Future<ReciteOptions?> _pickOptions(BuildContext context, Sura s) async {
  final saved = await ReciteOptions.load();
  if (!context.mounted) return null;
  return showModalBottomSheet<ReciteOptions>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OptionsSheet(sura: s, initial: saved),
  );
}

class _OptionsSheet extends StatefulWidget {
  final Sura sura;
  final ReciteOptions initial;
  const _OptionsSheet({required this.sura, required this.initial});

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late int _aya = 1;
  late bool _help = widget.initial.help;
  late int _delay = widget.initial.helpDelay;
  late bool _lenient = widget.initial.lenient;

  @override
  Widget build(BuildContext context) {
    final max = widget.sura.ayahs;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.sura.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heading)),
          const SizedBox(height: 16),
          Text("ابدأ من الآية $_aya",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18)),
          if (max > 1)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _aya > 1 ? () => setState(() => _aya--) : null,
                ),
                Expanded(
                  child: Slider(
                    value: _aya.toDouble(),
                    min: 1,
                    max: max.toDouble(),
                    divisions: max - 1,
                    label: "$_aya",
                    onChanged: (v) => setState(() => _aya = v.round()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _aya < max ? () => setState(() => _aya++) : null,
                ),
              ],
            ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _help,
            onChanged: (v) => setState(() => _help = v),
            secondary: const Icon(Icons.support_agent_rounded, color: _teal),
            title: const Text("المساعدة"),
            subtitle: const Text(
                "لو توقّف القارئ، يُنطق له الكلمة التالية ليكمل وحده"),
          ),
          if (_help) ...[
            const Text("بعد كم ثانية من التوقف؟"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in [3, 5, 8, 12])
                  ChoiceChip(
                    label: Text("$d ثوان"),
                    selected: _delay == d,
                    onSelected: (_) => setState(() => _delay = d),
                  ),
              ],
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _lenient,
            onChanged: (v) => setState(() => _lenient = v),
            secondary: const Icon(Icons.child_care_rounded, color: _teal),
            title: const Text("تساهل في النطق"),
            subtitle: const Text("للأطفال أو النطق غير الواضح"),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final o = ReciteOptions(
                  startAya: _aya,
                  help: _help,
                  helpDelay: _delay,
                  lenient: _lenient);
              o.save();
              Navigator.pop(context, o);
            },
            icon: const Icon(Icons.mic_rounded),
            label: const Text("ابدأ التسميع"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
            ),
          ),
        ],
      ),
    );
  }
}

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
                  onTap: () async {
                    final o = await _pickOptions(context, s);
                    if (o == null || !context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReciteView(sura: s, options: o)),
                    );
                  },
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
  final List<String> audio; // per-word pronunciation clip ('' if none)
  _Ayah(this.verse, this.display, this.expected, this.audio);
}

class ReciteView extends StatefulWidget {
  final Sura sura;
  final ReciteOptions options;
  const ReciteView(
      {super.key, required this.sura, this.options = const ReciteOptions()});

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

  // --- help: say the next word when the reciter is stuck ---
  Timer? _helpTimer;
  bool _helping = false; // mic paused while the hint plays
  final Set<int> _helped = {}; // word indices in the current ayah
  int _helpCount = 0;
  int _progress = 0; // correct words so far in this ayah
  DateTime? _helpEndedAt;
  int _sinceHelp() => _helpEndedAt == null
      ? 999
      : DateTime.now().difference(_helpEndedAt!).inSeconds;

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
      final audio = words.map((w) => w.audio).toList();
      ayat.add(display.isEmpty
          ? _Ayah(v, v.text.split(' '), tokens(v.text),
              List.filled(v.text.split(' ').length, ''))
          : _Ayah(v, display, expected, audio));
    }
    final ok = await _speech.initialize(
      onStatus: _onStatus,
      onError: (e) {
        // no-speech timeouts are normal pauses, not errors worth showing
        const silent = {'error_no_match', 'error_speech_timeout'};
        // the mic briefly fails while it hands the audio session back after a
        // help clip; that's expected and retried, not a user-facing error
        if (!mounted ||
            _helping ||
            _sinceHelp() < 3 ||
            silent.contains(e.errorMsg)) {
          return;
        }
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
      _i = (widget.options.startAya - 1).clamp(0, ayat.length - 1);
      _states = List.filled(ayat[_i].expected.length, WordState.pending);
      _ready = ok;
      if (!ok) _error = "التعرّف على الصوت غير متاح على هذا الجهاز";
    });
  }

  void _onStatus(String status) {
    final listening = status == 'listening';
    if (mounted) {
      setState(() {
        _listening = listening;
        if (listening) _error = null; // recovered
      });
    }
    if (listening) _armHelp();
    // engines stop after a pause; keep going while the user wants to recite
    if ((status == 'done' || status == 'notListening') &&
        _active &&
        !_helping) {
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
          // longer than the help delay, so help fires before the engine
          // gives up on silence
          pauseFor: Duration(seconds: widget.options.helpDelay + 5),
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
        a.expected, heard.skip(_consumed.clamp(0, heard.length)).toList(),
        lenient: widget.options.lenient);
    final progress = states.where((x) => x == WordState.correct).length;
    if (progress != _progress) {
      _progress = progress;
      _armHelp(); // moving again: restart the stuck countdown
    }
    setState(() => _states = states);
    if (states.isNotEmpty && states.last == WordState.correct) _advance();
  }

  void _advance() {
    // words given by the helper don't count toward accuracy
    _correctWords += [
      for (var k = 0; k < _states.length; k++)
        if (_states[k] == WordState.correct && !_helped.contains(k)) k
    ].length;
    _totalWords += _states.length;
    if (_i + 1 >= _ayat.length) {
      _stop();
      _finish();
      return;
    }
    _consumed = _heard.length;
    _partial = '';
    _helped.clear();
    _progress = 0;
    _armHelp();
    setState(() {
      _i++;
      _states = List.filled(_ayat[_i].expected.length, WordState.pending);
    });
  }

  void _armHelp() {
    _helpTimer?.cancel();
    if (!widget.options.help || !_active) return;
    _helpTimer = Timer(Duration(seconds: widget.options.helpDelay), _giveHelp);
  }

  /// Pause the mic (so it doesn't hear the hint), play the next word's
  /// recorded pronunciation, then listen again. The word is NOT counted:
  /// it stays hidden until the reciter says it themself, and the hint
  /// repeats every [helpDelay] seconds until they do.
  Future<void> _giveHelp() async {
    if (!_active || _helping || !mounted) return;
    final idx = _states.indexOf(WordState.pending);
    if (idx < 0) return;
    final a = _ayat[_i];
    _helping = true;
    if (!_helped.contains(idx)) _helpCount++; // distinct words, not repeats
    if (_speech.isListening) {
      await _speech.stop();
      for (var t = 0; t < 20 && _speech.isListening; t++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    _heardBefore = [..._heardBefore, ..._heardNow];
    _heardNow = [];
    setState(() => _helped.add(idx));
    final clip = idx < a.audio.length ? a.audio[idx] : '';
    if (clip.isNotEmpty) {
      final p = QuranPlayer.instance;
      await p.playClip('${AppConstants.wordAudioBaseUrl}$clip',
          title: a.display[idx]);
      await p.player.processingStateStream
          .firstWhere((st) => st == ProcessingState.completed)
          .timeout(const Duration(seconds: 6),
              onTimeout: () => ProcessingState.completed);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    _helping = false;
    _helpEndedAt = DateTime.now();
    if (_active && mounted) {
      await _listen();
      _armHelp();
    }
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
    _helpTimer?.cancel();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("دقة التلاوة: $pct%",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22)),
            if (_helpCount > 0)
              Text("ساعدتك في $_helpCount كلمة",
                  style: TextStyle(color: Colors.orange.shade700)),
          ],
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
    _helpTimer?.cancel();
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
          _word(
              a.display[k], k < _states.length ? _states[k] : WordState.pending,
              helped: _helped.contains(k)),
      ],
    );
  }

  Widget _word(String text, WordState s, {bool helped = false}) {
    final hidden = _hideText && s == WordState.pending;
    final color = helped && s == WordState.correct
        ? Colors.orange.shade700
        : switch (s) {
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
              // hinted word still waiting for the reciter to say it
              color: helped ? AppColors.amberSoft : AppColors.tealSoft,
              borderRadius: BorderRadius.circular(8),
              border: helped ? Border.all(color: Colors.orange.shade300) : null,
            ),
            child: helped
                ? Icon(Icons.volume_up_rounded,
                    size: 18, color: Colors.orange.shade400)
                : null,
          )
        : Text(text, style: TextStyle(fontSize: 26, height: 1.8, color: color));
  }
}
