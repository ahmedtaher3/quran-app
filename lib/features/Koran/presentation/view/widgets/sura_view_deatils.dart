import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/repo/quran_repository.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/verse_card.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/audio_player_sheet.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/audio/downloads_view.dart';

class VerseListView extends StatefulWidget {
  final int suraNumber;
  final String SuraName;
  final int? ayaNumber;
  const VerseListView(
      {super.key,
      required this.suraNumber,
      this.ayaNumber,
      required this.SuraName});
  @override
  State<VerseListView> createState() => _VerseListViewState();
}

class _VerseListViewState extends State<VerseListView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> verseKeys = {};

  bool _hasScrolledToInitialAyah = false;
  bool _shouldScrollToSavedPosition = false; // New flag
  int? _flashHighlightVerseId;
  int? _lastScrolledAyahId;

  GlobalKey _verseKeyFor(int verseId) {
    return verseKeys.putIfAbsent(verseId, () => GlobalKey());
  }

  Future<void> _scrollToVerse({
    required int verseId,
    required int index,
    required int itemCount,
    bool markInitial = false,
  }) async {
    if (!mounted ||
        !_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }

    double _estimatedOffset() {
      final position = _scrollController.position;
      final totalExtent = position.maxScrollExtent + position.viewportDimension;
      final estimate = (totalExtent * index) / itemCount;
      return estimate.clamp(0.0, position.maxScrollExtent);
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      if (!mounted) return;
      final targetContext = verseKeys[verseId]?.currentContext;
      if (targetContext != null) {
        if (markInitial) _hasScrolledToInitialAyah = true;
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: Duration(milliseconds: 500 + attempt * 120),
          curve: Curves.easeInOut,
        );
        return;
      }

      final offset = _estimatedOffset();
      if (_scrollController.hasClients &&
          offset <= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(offset);
      }
      await Future.delayed(Duration(milliseconds: 80));
    }
  }

  Future<void> _scrollToInitialAyah(VerseLoaded state) async {
    if (!mounted) return;
    if (_hasScrolledToInitialAyah || widget.ayaNumber == null) return;

    final targetIndex =
        state.verses.indexWhere((verse) => verse.ayaNumber == widget.ayaNumber);
    if (targetIndex == -1) return;

    final targetVerse = state.verses[targetIndex];
    await _scrollToVerse(
      verseId: targetVerse.id,
      index: targetIndex,
      itemCount: state.verses.length,
      markInitial: true,
    );
    _flashHighlight(targetVerse.id);
  }

  // دالة لمتابعة الآية التي تعمل حالياً وعمل Scroll إليها
  void _scrollToPlayingVerse(VerseLoaded state) {
    if (state.playingAyahId == null ||
        state.playingAyahId == _lastScrolledAyahId) return;

    final index = state.verses.indexWhere((v) => v.id == state.playingAyahId);
    if (index != -1) {
      _lastScrolledAyahId =
          state.playingAyahId; // حفظ الآية لعدم تكرار الـ Scroll
      _scrollToVerse(
        verseId: state.playingAyahId!,
        index: index,
        itemCount: state.verses.length,
      );
    }
  }

  /// 🔥 دالة الحصول على الآية الموجودة في منتصف الشاشة
  int? _getMiddleAyahId(List verses) {
    try {
      final screenHeight = MediaQuery.of(context).size.height;
      final middleY = screenHeight / 2;

      for (var v in verses) {
        final ctx = verseKeys[v.id]?.currentContext;
        if (ctx == null) continue;

        final render = ctx.findRenderObject() as RenderBox?;
        if (render == null) continue;

        final pos = render.localToGlobal(Offset.zero).dy;
        final h = render.size.height;

        if (pos <= middleY && pos + h >= middleY) {
          return v.id;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Verses fully or partly on screen — counted as read for stats.
  List<int> _visibleAyahIds(List verses) {
    final h = MediaQuery.of(context).size.height;
    final ids = <int>[];
    for (final v in verses) {
      final ctx = verseKeys[v.id]?.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top < h && top + box.size.height > 0) ids.add(v.id);
    }
    return ids;
  }

  bool _loggedInitial = false;

  void _flashHighlight(int verseId) {
    if (!mounted) return;
    setState(() {
      _flashHighlightVerseId = verseId;
    });
    Future.delayed(Duration(seconds: 1), () {
      if (!mounted) return;
      if (_flashHighlightVerseId == verseId) {
        setState(() {
          _flashHighlightVerseId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop(BuildContext context, VerseState state) async {
    if (state is VerseLoaded && state.playingAyahId != null) {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تنبيه", style: TextStyle(fontFamily: 'Hafs')),
          content: const Text(
            "هل تريد إيقاف التلاوة أم الاستمرار في الخلفية؟",
            style: TextStyle(fontFamily: 'Hafs'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<VerseCubit>().stopSequentialPlay();
                Navigator.pop(dialogContext, true);
              },
              child: const Text("إيقاف",
                  style: TextStyle(color: Colors.red, fontFamily: 'Hafs')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("استمرار",
                  style: TextStyle( color: Colors.teal)),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          VerseCubit(QuranRepository())
            ..suraName = widget.SuraName
            ..loadVerses(widget.suraNumber,
              skipContinueDialog: widget.ayaNumber != null),
      child: BlocBuilder<VerseCubit, VerseState>(
        builder: (context, state) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await _onWillPop(context, state);
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFF9FBF9),
              body: Builder(
                builder: (innerContext) {
                  String suraTitle = "آيات السورة";
                  if (state is VerseLoaded && state.verses.isNotEmpty) {
                    suraTitle = widget.SuraName?.toString() ?? "سورة القران";
                  }

                  return NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      if (state is VerseLoaded) {
                        DBHelper.logVerses(_visibleAyahIds(state.verses));
                        final midAyah = _getMiddleAyahId(state.verses);
                        if (midAyah != null) {
                          innerContext.read<VerseCubit>().updateReadingPosition(
                                widget.suraNumber,
                                midAyah,
                              );
                        }
                      }
                      return true;
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 200.0,
                          floating: false,
                          pinned: true,
                          leading: const BackButton(color: Colors.white),
                          actions: [
                            SuraDownloadButton(sura: widget.suraNumber),
                          ],
                          backgroundColor: const Color(0xFF00695C),
                          flexibleSpace: FlexibleSpaceBar(
                            centerTitle: true,
                            title: Text(
                              suraTitle,
                              style: const TextStyle(
                                
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                            background: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF004D40),
                                    Color(0xFF00796B)
                                  ],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    bottom: -20,
                                    left: -20,
                                    child: Icon(
                                      Icons.mosque,
                                      size: 180,
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 20),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: BlocListener<VerseCubit, VerseState>(
                            listener: (context, state) {
                              if (state is VerseLoaded) {
                                // short suras may never scroll: log what's
                                // on screen after the reader had time to read
                                if (!_loggedInitial) {
                                  _loggedInitial = true;
                                  Future.delayed(const Duration(seconds: 5),
                                      () {
                                    if (mounted) {
                                      DBHelper.logVerses(
                                          _visibleAyahIds(state.verses));
                                    }
                                  });
                                }
                                // التمرير للآية التي تعمل حالياً
                                if (state.playingAyahId != null) {
                                  _scrollToPlayingVerse(state);
                                }

                                if (!_hasScrolledToInitialAyah &&
                                    widget.ayaNumber != null) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollToInitialAyah(state);
                                  });
                                }

                                // التمرير للموضع المحفوظ عند الضغط على "نعم، متابعة"
                                if (_shouldScrollToSavedPosition &&
                                    state.lastViewedAyahId != null) {
                                  _shouldScrollToSavedPosition = false;
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    final index = state.verses.indexWhere(
                                        (v) => v.id == state.lastViewedAyahId);
                                    if (index != -1) {
                                      _scrollToVerse(
                                        verseId: state.lastViewedAyahId!,
                                        index: index,
                                        itemCount: state.verses.length,
                                      );
                                      _flashHighlight(state.lastViewedAyahId!);
                                    }
                                  });
                                }

                                if (state.showContinueDialog) {
                                  Future.delayed(
                                      const Duration(milliseconds: 300), () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("متابعة القراءة"),
                                        content: const Text(
                                            "تريد تكملة القراءة من حيث توقفت؟"),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              setState(() {
                                                _shouldScrollToSavedPosition =
                                                    true;
                                              });
                                              context
                                                  .read<VerseCubit>()
                                                  .continueFromLastAyah();
                                            },
                                            child: const Text("نعم، متابعة"),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              context
                                                  .read<VerseCubit>()
                                                  .resetProgress(
                                                      widget.suraNumber);
                                            },
                                            child: const Text("البدء من جديد"),
                                          ),
                                        ],
                                      ),
                                    );
                                  });
                                }
                              }
                            },
                            child: const SizedBox(),
                          ),
                        ),
                        BlocBuilder<VerseCubit, VerseState>(
                          builder: (context, state) {
                            if (state is VerseLoading) {
                              return const SliverFillRemaining(
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (state is VerseLoaded) {
                              return SliverPadding(
                                padding: const EdgeInsets.only(bottom: 20),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final verse = state.verses[index];
                                      return VerseCard(
                                        key: _verseKeyFor(verse.id),
                                        verse: verse,
                                        bookmark: state.bookmarks[verse.id],
                                        isPlaying:
                                            verse.id == state.playingAyahId,
                                        highlight: verse.id ==
                                                _flashHighlightVerseId ||
                                            verse.id ==
                                                state.lastViewedAyahId ||
                                            verse.id == state.playingAyahId,
                                      );
                                    },
                                    childCount: state.verses.length,
                                  ),
                                ),
                              );
                            }
                            return const SliverToBoxAdapter(child: SizedBox());
                          },
                        ),
                      ],
                    ),
                  ); // NotificationListener
                },
              ),
              floatingActionButton: state is! VerseLoaded
                  ? null
                  : state.playingAyahId != null
                      ? _MiniPlayer(
                          verse: state.verses.firstWhere(
                              (v) => v.id == state.playingAyahId,
                              orElse: () => state.verses.first),
                          suraName: widget.SuraName,
                          onStop: () =>
                              context.read<VerseCubit>().stopSequentialPlay(),
                        )
                      : _PlayAllButton(
                          isPlaying: false,
                          onTap: () =>
                              context.read<VerseCubit>().startSequentialPlay(),
                        ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
            ),
          );
        },
      ),
    );
  }
}

class _PlayAllButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayAllButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPlaying
                    ? [const Color(0xFFC62828), const Color(0xFFB71C1C)]
                    : [const Color(0xFF00695C), const Color(0xFF004D40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color:
                      (isPlaying ? Colors.red : Colors.teal).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isPlaying ? "إيقاف التشغيل" : "تشغيل الكل",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final Verse verse;
  final String suraName;
  final VoidCallback onStop;
  const _MiniPlayer(
      {required this.verse, required this.suraName, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final qp = QuranPlayer.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        elevation: 8,
        shadowColor: Colors.teal.withOpacity(0.3),
        color: const Color(0xFF004D40),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => showPlayerSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$suraName - آية ${verse.ayaNumber}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(qp.reciterName,
                          maxLines: 1,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "الآية السابقة",
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                  onPressed: qp.previous,
                ),
                StreamBuilder<bool>(
                  stream: qp.player.playingStream,
                  initialData: qp.player.playing,
                  builder: (_, snap) => IconButton(
                    icon: Icon(
                        snap.data == true
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 40),
                    onPressed: () => snap.data == true
                        ? qp.player.pause()
                        : qp.player.play(),
                  ),
                ),
                IconButton(
                  tooltip: "الآية التالية",
                  icon: const Icon(Icons.skip_previous_rounded,
                      color: Colors.white),
                  onPressed: qp.next,
                ),
                IconButton(
                  tooltip: "إيقاف",
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: onStop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
