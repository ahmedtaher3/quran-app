import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/core/constants/app_constants.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/data/model/bookmark.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/reader_controls.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/share/share_ayah.dart';
import 'package:untitled/features/tafsir/tafsir_sheet.dart';
import 'package:untitled/words_dialog.dart';

const _teal = Color(0xFF00695C);
const _selectedBg = Color(0x55FFB300); // tapped word / word being recited
const _flashBg = Color(0x40FFCA28); // ayah just jumped to, or its menu open
const _playingBg = Color(0x2600897B); // ayah being recited
String _ar(int n) => arNum(n);

typedef _AyahBox = ({int id, double top, double bottom});

class FlowWord {
  final int id, ayahId, aya, page;
  final int quarter; // hizbQuarter, 1..240
  final bool sajda;
  final String text, audio, english;
  final String arabic; // Arabic meaning; often shared by a short phrase
  final String? source; // tafsir the meaning was checked against
  int pos = 0; // 1-based position in its ayah, matches the recitation timing
  bool get hasMeaning => arabic.isNotEmpty;
  FlowWord(Map<String, Object?> r)
      : id = r['id'] as int,
        ayahId = r['ayaID'] as int,
        aya = r['ayaNumber'] as int,
        page = r['page'] as int,
        quarter = r['hizbQuarter'] as int? ?? 0,
        sajda = (r['sajda'] as int? ?? 0) != 0,
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
/// see its meaning; tap an ayah's number, or long-press any of its words,
/// for everything the ayah cards offer (play, tafsir, word meanings, share,
/// bookmark).
///
/// Needs the [VerseCubit] from [VerseListView] above it.
class FlowSuraView extends StatefulWidget {
  final int sura;
  final String suraName;
  final int? ayaNumber; // open at this ayah (search, bookmarks, continue)
  final Widget? footer; // previous / next sura
  const FlowSuraView(
      {super.key,
      required this.sura,
      required this.suraName,
      this.ayaNumber,
      this.footer});

  @override
  State<FlowSuraView> createState() => _FlowSuraViewState();
}

class _FlowSuraViewState extends State<FlowSuraView> {
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  final _pageKeys = <int, GlobalKey<_PageParagraphState>>{};
  final _ayahPage = <int, int>{}; // ayahId -> page index
  final _ayahIdByNumber = <int, int>{};
  final _ayahWords = <int, List<int>>{}; // ayahId -> word ids, in order
  Set<int> _quarterStarts = {}; // ayahs that open a hizb quarter (۞)
  List<List<FlowWord>>? _pages;
  int? _selected;
  int? _flashAyah;
  int? _pendingAyah; // jump requested before the pages loaded
  int? _followed; // recited ayah already brought into view
  bool _userScrolling = false;
  bool _following = false; // a follow scroll is animating
  DateTime _lastUserScroll = DateTime(0);
  StreamSubscription<int?>? _recitedWord;

  bool get _hasBasmala => widget.sura != 1 && widget.sura != 9;

  /// The reader scrolled away during a recitation: let them look around
  /// for a moment before following the reciter again.
  bool get _userScrolledRecently =>
      DateTime.now().difference(_lastUserScroll) < const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _load();
    _recitedWord = QuranPlayer.instance.currentWord.listen(_followWord);
  }

  @override
  void dispose() {
    _recitedWord?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final words = (await DBHelper.getFlowWords(widget.sura)).map(FlowWord.new);
    final pages = <List<FlowWord>>[];
    int? ayah;
    var pos = 0;
    for (final w in words) {
      pos = w.ayahId == ayah ? pos + 1 : 1;
      ayah = w.ayahId;
      w.pos = pos;
      if (pages.isEmpty || pages.last.first.page != w.page) pages.add([]);
      pages.last.add(w);
      _ayahPage.putIfAbsent(w.ayahId, () => pages.length - 1);
      _ayahIdByNumber[w.aya] = w.ayahId;
      (_ayahWords[w.ayahId] ??= []).add(w.id);
    }
    final quarterStarts = await DBHelper.quarterStarts(widget.sura);
    if (!mounted) return;
    setState(() {
      _quarterStarts = quarterStarts;
      _pages = pages;
    });

    final start = widget.ayaNumber == null
        ? null
        : _ayahIdByNumber[widget.ayaNumber];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _pendingAyah ?? start;
      _pendingAyah = null;
      if (target != null) _goToAyah(target);
    });
    // short suras may never scroll: log what's on screen after the reader
    // had time to read
    Future.delayed(const Duration(seconds: 5), () {
      final view = _viewRect();
      if (mounted && view != null) {
        DBHelper.logVerses(_onScreenAyahs(view).map((a) => a.id));
      }
    });
  }

  // ---- geometry ----------------------------------------------------------

  Rect? _viewRect() {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Ayahs on screen, top to bottom, in global coordinates.
  List<_AyahBox> _onScreenAyahs(Rect view) {
    final out = <_AyahBox>[];
    for (final p in _pageKeys.keys.toList()..sort()) {
      for (final a in _pageKeys[p]!.currentState?.ayahBoxes() ?? <_AyahBox>[]) {
        if (a.bottom > view.top && a.top < view.bottom) out.add(a);
      }
    }
    return out;
  }

  /// Rough scroll offset of page [page], from the pages laid out so far.
  double _estimateOffset(int page, Rect view) {
    final pos = _scroll.position;
    final built = <int, Rect>{};
    _pageKeys.forEach((i, k) {
      final r = k.currentState?.rect();
      if (r != null) built[i] = r;
    });
    if (built.isEmpty) {
      final count = _pages!.length + (_hasBasmala ? 1 : 0);
      final index = page + (_hasBasmala ? 1 : 0);
      return (pos.maxScrollExtent + pos.viewportDimension) * index / count;
    }
    final first = built.keys.reduce(math.min);
    final last = built.keys.reduce(math.max);
    final ref = page > last ? last : first;
    final avg =
        built.values.map((r) => r.height).reduce((a, b) => a + b) / built.length;
    return pos.pixels + built[ref]!.top - view.top + (page - ref) * avg;
  }

  /// Scrolls so [ayahId] starts [alignment] of the way down the screen.
  Future<void> _scrollToAyah(int ayahId, {double alignment = 0.25}) async {
    final page = _ayahPage[ayahId];
    if (page == null) return;
    for (var attempt = 0; attempt < 12; attempt++) {
      if (!mounted || !_scroll.hasClients) return;
      final view = _viewRect();
      if (view == null) return;
      final pos = _scroll.position;
      final box = _pageKeys[page]?.currentState?.ayahBox(ayahId);
      if (box != null) {
        final target =
            (pos.pixels + box.top - view.top - view.height * alignment)
                .clamp(pos.minScrollExtent, pos.maxScrollExtent);
        if (attempt == 0) {
          await _scroll.animateTo(target,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut);
        } else {
          _scroll.jumpTo(target); // came from far away; don't animate
        }
        return;
      }
      _scroll.jumpTo(_estimateOffset(page, view)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _goToAyah(int ayahId) async {
    if (_pages == null) {
      _pendingAyah = ayahId;
      return;
    }
    await _scrollToAyah(ayahId);
    _flash(ayahId);
  }

  void _flash(int ayahId) {
    if (!mounted) return;
    setState(() => _flashAyah = ayahId);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _flashAyah == ayahId) setState(() => _flashAyah = null);
    });
  }

  /// Keeps the ayah being recited on screen without jumping for every ayah.
  void _follow(int ayahId) {
    if (_followed == ayahId) return;
    if (_pages == null) {
      _pendingAyah ??= ayahId;
      return;
    }
    if (_userScrolledRecently) return; // the word follow catches up later
    _followed = ayahId;
    final view = _viewRect();
    final box = _pageKeys[_ayahPage[ayahId]]?.currentState?.ayahBox(ayahId);
    if (view != null &&
        box != null &&
        box.top >= view.top + view.height * 0.05 &&
        box.top <= view.top + view.height * 0.6) {
      return;
    }
    _scrollToAyah(ayahId, alignment: 0.2);
  }

  /// Long ayahs run past the screen: keep the word being recited in view.
  Future<void> _followWord(int? pos) async {
    if (pos == null || _pages == null || _following || !mounted) return;
    if (_userScrolledRecently) return;
    final state = context.read<VerseCubit>().state;
    final ayah = state is VerseLoaded ? state.playingAyahId : null;
    final words = _ayahWords[ayah];
    if (ayah == null || words == null || pos > words.length) return;
    final view = _viewRect();
    final box =
        _pageKeys[_ayahPage[ayah]]?.currentState?.wordBox(words[pos - 1]);
    if (view == null || box == null || !_scroll.hasClients) return;
    if (box.top >= view.top + view.height * 0.1 &&
        box.bottom <= view.top + view.height * 0.75) {
      return; // comfortably on screen
    }
    final p = _scroll.position;
    _following = true;
    try {
      await _scroll.animateTo(
          (p.pixels + box.top - view.top - view.height * 0.3)
              .clamp(p.minScrollExtent, p.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    } finally {
      _following = false;
    }
  }

  // ---- reading position & stats -------------------------------------------

  bool _onScrollNotification(ScrollNotification n) {
    if ((n is ScrollStartNotification && n.dragDetails != null) ||
        (n is ScrollUpdateNotification && n.dragDetails != null)) {
      _lastUserScroll = DateTime.now();
    }
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userScrolling = true;
    } else if (n is ScrollEndNotification) {
      _onScrollEnd(saveSpot: _userScrolling);
      _userScrolling = false;
    }
    return false;
  }

  /// Logs what was on screen for stats, and after the reader's own scroll
  /// saves the ayah at the reading line as the place to continue from.
  /// Jumps the app makes itself are not saved, so the spot never drifts.
  void _onScrollEnd({required bool saveSpot}) {
    final view = _viewRect();
    if (view == null) return;
    final ayahs = _onScreenAyahs(view);
    if (ayahs.isEmpty) return;
    DBHelper.logVerses(ayahs.map((a) => a.id));
    if (!saveSpot) return;
    final line = view.top + view.height * 0.25;
    final atTop = _scroll.position.pixels <= _scroll.position.minScrollExtent;
    final spot = atTop
        ? ayahs.first
        : ayahs.firstWhere((a) => a.top <= line && a.bottom >= line,
            orElse: () => ayahs.firstWhere((a) => a.top >= line,
                orElse: () => ayahs.last));
    context.read<VerseCubit>().updateReadingPosition(widget.sura, spot.id);
  }

  void _onState(BuildContext context, VerseState state) {
    if (state is! VerseLoaded) return;
    final playing = state.playingAyahId;
    if (playing == null) {
      _followed = null;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow(playing));
    }
    if (state.showContinueDialog) {
      final cubit = context.read<VerseCubit>();
      showContinueReadingDialog(
        context,
        onContinue: () {
          final id = cubit.lastViewedAyahId;
          if (id != null) _goToAyah(id);
        },
        onRestart: () => cubit.resetProgress(widget.sura),
      );
    }
  }

  // ---- taps ----------------------------------------------------------------

  Future<void> _onWord(FlowWord w) async {
    setState(() => _selected = w.id);
    final qp = QuranPlayer.instance;
    final reciting = qp.player.playing && qp.queue.isNotEmpty;
    // don't cut the recitation off; "إعادة النطق" still plays the word
    if (w.audio.isNotEmpty && !reciting) {
      QuranPlayer.instance
          .playClip('${AppConstants.wordAudioBaseUrl}${w.audio}', title: w.text);
    }
    await showModalBottomSheet(
      context: context,
      // size to content; long meanings scroll instead of overflowing
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WordSheet(
          word: w, suraName: widget.suraName, parent: context, onAyah: _onAyah),
    );
    if (mounted) setState(() => _selected = null);
  }

  /// The ayah card's actions, for the ayah whose number was tapped.
  Future<void> _onAyah(int ayahId) async {
    final state = context.read<VerseCubit>().state;
    if (state is! VerseLoaded) return;
    final verse = state.verses.where((v) => v.id == ayahId).firstOrNull;
    if (verse == null) return;
    final bookmark = state.bookmarks[ayahId];
    setState(() => _flashAyah = ayahId);
    final action = await showModalBottomSheet<_AyahAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AyahSheet(
          verse: verse, suraName: widget.suraName, bookmark: bookmark),
    );
    if (!mounted) return;
    setState(() => _flashAyah = null);
    switch (action) {
      case null:
        return;
      case _AyahAction.play:
        playSingleAyah(context, verse);
      case _AyahAction.playFrom:
        context.read<VerseCubit>().playSequentiallyFrom(verse.id);
      case _AyahAction.tafsir:
        showTafsirSheet(context, verse);
      case _AyahAction.words:
        final words = await DBHelper.getWordsByAyah(verse.id);
        if (!mounted) return;
        showDialog(context: context, builder: (_) => WordsDialog(words: words));
      case _AyahAction.share:
        showShareAyah(context, verse, suraName: widget.suraName);
      case _AyahAction.bookmark:
        await editAyahBookmark(context, verse, bookmark);
    }
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VerseCubit, VerseState>(
      listener: _onState,
      builder: (context, state) {
        final loaded = state is VerseLoaded ? state : null;
        final pages = _pages;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final ok = await confirmLeaveWhilePlaying(context, state);
            if (ok && context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar:
                readerAppBar(sura: widget.sura, suraName: widget.suraName),
            body: pages == null
                ? const Center(child: CircularProgressIndicator())
                : NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: ListView.builder(
                      key: _listKey,
                      controller: _scroll,
                      // room for the play button / mini player
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: pages.length +
                          (_hasBasmala ? 1 : 0) +
                          (widget.footer != null ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == pages.length + (_hasBasmala ? 1 : 0)) {
                          return widget.footer!;
                        }
                        if (_hasBasmala && i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                              textAlign: TextAlign.center,
                              style: AppSettings.instance.quranStyle(
                                  scale: 1.05, color: AppColors.heading),
                            ),
                          );
                        }
                        final p = i - (_hasBasmala ? 1 : 0);
                        return _PageParagraph(
                          key: _pageKeys.putIfAbsent(p, GlobalKey.new),
                          words: pages[p],
                          selected: _selected,
                          flashAyah: _flashAyah,
                          playingAyah: loaded?.playingAyahId,
                          bookmarks: loaded?.bookmarks ?? const {},
                          quarterStarts: _quarterStarts,
                          onWord: _onWord,
                          onAyah: _onAyah,
                        );
                      },
                    ),
                  ),
            floatingActionButton: readerFab(context, state, widget.suraName),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        );
      },
    );
  }
}

class _PageParagraph extends StatefulWidget {
  final List<FlowWord> words;
  final int? selected, flashAyah, playingAyah;
  final Map<int, Bookmark> bookmarks;
  final Set<int> quarterStarts;
  final void Function(FlowWord) onWord;
  final void Function(int ayahId) onAyah;
  const _PageParagraph(
      {super.key,
      required this.words,
      required this.selected,
      required this.flashAyah,
      required this.playingAyah,
      required this.bookmarks,
      required this.quarterStarts,
      required this.onWord,
      required this.onAyah});

  @override
  State<_PageParagraph> createState() => _PageParagraphState();
}

class _PageParagraphState extends State<_PageParagraph> {
  final _textKey = GlobalKey();
  // recognizers owned here so they're disposed with the page
  late final _taps = [
    for (final w in widget.words)
      TapGestureRecognizer()..onTap = () => widget.onWord(w)
  ];
  late final _ayahTaps = <int, TapGestureRecognizer>{
    for (final w in widget.words)
      w.ayahId: TapGestureRecognizer()..onTap = () => widget.onAyah(w.ayahId)
  };
  // text range of each ayah on this page, in reading order, and of each word
  final _ranges = <int, (int, int)>{};
  final _wordRanges = <int, (int, int)>{};

  @override
  void dispose() {
    for (final t in [..._taps, ..._ayahTaps.values]) {
      t.dispose();
    }
    super.dispose();
  }

  RenderParagraph? get _paragraph {
    RenderObject? r = _textKey.currentContext?.findRenderObject();
    while (r != null && r is! RenderParagraph) {
      RenderObject? child;
      r.visitChildren((c) => child ??= c);
      r = child;
    }
    final p = r as RenderParagraph?;
    return p != null && p.attached && p.hasSize ? p : null;
  }

  _AyahBox? _box(RenderParagraph p, int id, [Map<int, (int, int)>? of]) {
    final range = (of ?? _ranges)[id];
    if (range == null) return null;
    final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: range.$1, extentOffset: range.$2));
    if (boxes.isEmpty) return null;
    var top = double.infinity, bottom = double.negativeInfinity;
    for (final b in boxes) {
      top = math.min(top, b.top);
      bottom = math.max(bottom, b.bottom);
    }
    final y = p.localToGlobal(Offset.zero).dy;
    return (id: id, top: y + top, bottom: y + bottom);
  }

  _AyahBox? ayahBox(int id) {
    final p = _paragraph;
    return p == null ? null : _box(p, id);
  }

  _AyahBox? wordBox(int wordId) {
    final p = _paragraph;
    return p == null ? null : _box(p, wordId, _wordRanges);
  }

  /// Long-press anywhere in an ayah opens its menu: the number alone is a
  /// small target.
  void _onLongPress(LongPressStartDetails d) {
    final p = _paragraph;
    if (p == null) return;
    final at = p.getPositionForOffset(p.globalToLocal(d.globalPosition)).offset;
    for (final e in _ranges.entries) {
      if (at >= e.value.$1 && at <= e.value.$2) {
        HapticFeedback.selectionClick();
        widget.onAyah(e.key);
        return;
      }
    }
  }

  List<_AyahBox> ayahBoxes() {
    final p = _paragraph;
    if (p == null) return const [];
    return [
      for (final id in _ranges.keys)
        if (_box(p, id) case final b?) b
    ];
  }

  Rect? rect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.playingAyah;
    final recitingHere = playing != null && _ayahTaps.containsKey(playing);
    return Column(
      children: [
        GestureDetector(
          onLongPressStart: _onLongPress,
          // only the page being recited rebuilds on every word
          child: recitingHere
              ? StreamBuilder<int?>(
                  stream: QuranPlayer.instance.currentWord,
                  builder: (_, snap) => _text(snap.data),
                )
              : _text(null),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.teal.shade100)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                    widget.words.first.quarter > 0
                        ? "${_ar(widget.words.first.page)} • الجزء ${_ar(juzOf(widget.words.first.quarter))}"
                        : _ar(widget.words.first.page),
                    style: TextStyle(color: AppColors.subtle, fontSize: 13)),
              ),
              Expanded(child: Divider(color: Colors.teal.shade100)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _text(int? recitedPos) {
    final words = widget.words;
    final dark = AppSettings.instance.isDark;
    final marker =
        TextStyle(color: dark ? Colors.teal.shade200 : Colors.teal.shade700);
    final meaning = dark ? const Color(0xFFFFCA6B) : const Color(0xFFB45309);
    final spans = <InlineSpan>[];
    var offset = 0; // in the paragraph's plain text; a WidgetSpan counts 1
    var start = 0;
    void add(InlineSpan s, int length) {
      spans.add(s);
      offset += length;
    }

    _ranges.clear();
    _wordRanges.clear();
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (i == 0 || words[i - 1].ayahId != w.ayahId) {
        start = offset;
        if (widget.quarterStarts.contains(w.ayahId) && w.quarter > 0) {
          // no-break spaces keep ۞, its label and the ayah's first word on
          // one line
          const nbsp = '\u00A0';
          add(TextSpan(text: '۞$nbsp', style: marker), 2);
          final label =
              '${quarterLabel(w.quarter).replaceAll(' ', nbsp)}$nbsp';
          add(
              TextSpan(
                  text: label,
                  style: marker.copyWith(
                      fontSize: AppSettings.instance.quranSize * 0.55)),
              label.length);
        }
      }
      _wordRanges[w.id] = (offset, offset + w.text.length);
      final tint = w.ayahId == widget.flashAyah
          ? _flashBg
          : w.ayahId == playing
              ? _playingBg
              : null;
      final highlighted = w.id == widget.selected ||
          (w.ayahId == playing && w.pos == recitedPos);
      add(
          TextSpan(
            text: w.text,
            recognizer: _taps[i],
            style: highlighted
                ? const TextStyle(color: _teal, backgroundColor: _selectedBg)
                : TextStyle(
                    color: w.hasMeaning ? meaning : null, backgroundColor: tint),
          ),
          w.text.length);
      add(TextSpan(text: ' ', style: TextStyle(backgroundColor: tint)), 1);
      final ayahEnds = i + 1 == words.length || words[i + 1].ayahId != w.ayahId;
      if (!ayahEnds) continue;

      final bookmark = widget.bookmarks[w.ayahId];
      if (bookmark != null) {
        add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.bookmark_rounded,
                  size: AppSettings.instance.quranSize * 0.7,
                  color: Color(bookmark.color)),
            ),
            1);
      }
      final number = '﴿${_ar(w.aya)}﴾';
      add(
          TextSpan(
            text: number,
            recognizer: _ayahTaps[w.ayahId],
            style: bookmark == null
                ? marker
                : marker.copyWith(
                    color: Color(bookmark.color), fontWeight: FontWeight.bold),
          ),
          number.length);
      if (w.sajda) add(TextSpan(text: ' ۩', style: marker), 2);
      _ranges[w.ayahId] = (start, offset);
      add(const TextSpan(text: ' '), 1);
    }
    return Text.rich(
      TextSpan(children: spans),
      key: _textKey,
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      style: AppSettings.instance.quranStyle(),
    );
  }

  int? get playing => widget.playingAyah;
}

enum _AyahAction { play, playFrom, tafsir, words, share, bookmark }

/// Same actions as the ayah card's bar, as a menu.
class _AyahSheet extends StatelessWidget {
  final Verse verse;
  final String suraName;
  final Bookmark? bookmark;
  const _AyahSheet(
      {required this.verse, required this.suraName, required this.bookmark});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, Color color, String label, _AyahAction a) =>
        ListTile(
          leading: Icon(icon, color: color),
          title: Text(label),
          onTap: () => Navigator.pop(context, a),
        );
    final b = bookmark;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$suraName • آية ${_ar(verse.ayaNumber ?? 0)}",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.heading)),
            if (b != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(b.color).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bookmark_rounded, color: Color(b.color), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(b.note ?? "علامة محفوظة",
                          style: TextStyle(
                              fontSize: 14, color: Color(b.color), height: 1.5)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            item(Icons.play_arrow_rounded, _teal, "تشغيل الآية",
                _AyahAction.play),
            item(Icons.playlist_play_rounded, _teal, "تشغيل من هذه الآية",
                _AyahAction.playFrom),
            item(Icons.auto_stories_rounded, Colors.orange.shade800, "التفسير",
                _AyahAction.tafsir),
            item(Icons.language_rounded, Colors.blue.shade700, "معاني الكلمات",
                _AyahAction.words),
            item(Icons.ios_share_rounded, Colors.purple.shade400, "مشاركة الآية",
                _AyahAction.share),
            item(
                b != null
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                b != null ? Color(b.color) : Colors.grey.shade600,
                b != null ? "تعديل العلامة" : "إضافة علامة",
                _AyahAction.bookmark),
          ],
        ),
      ),
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
  final void Function(int ayahId) onAyah;
  const _WordSheet(
      {required this.word,
      required this.suraName,
      required this.parent,
      required this.onAyah});

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
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onAyah(word.ayahId);
              },
              icon: const Icon(Icons.more_horiz_rounded),
              label: const Text("خيارات الآية"),
            ),
          ],
        ),
      ),
    );
  }
}
