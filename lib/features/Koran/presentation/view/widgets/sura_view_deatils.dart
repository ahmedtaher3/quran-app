import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/repo/quran_repository.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/verse_card.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/reader_controls.dart';
import 'package:untitled/features/audio/downloads_view.dart';
import 'package:untitled/features/Koran/presentation/view/flow_sura_view.dart';
import 'package:untitled/core/app_theme.dart';

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

  Widget _modeToggle() {
    final flow = AppSettings.instance.flowReading;
    return IconButton(
      tooltip: flow ? "عرض الآيات كبطاقات" : "عرض متصل كالمصحف",
      icon: Icon(flow ? Icons.view_agenda_rounded : Icons.subject_rounded,
          color: Colors.white),
      onPressed: () => AppSettings.instance.update(flowReading: !flow),
    );
  }

  @override
  Widget build(BuildContext context) {
    // One cubit for both modes: switching keeps playback, bookmarks and the
    // reading position.
    return BlocProvider(
      create: (_) =>
          VerseCubit(QuranRepository())
            ..suraName = widget.SuraName
            ..loadVerses(widget.suraNumber,
              skipContinueDialog: widget.ayaNumber != null),
      child: AppSettings.instance.flowReading
          ? FlowSuraView(
              sura: widget.suraNumber,
              suraName: widget.SuraName,
              ayaNumber: widget.ayaNumber,
              modeToggle: _modeToggle(),
            )
          : _cards(),
    );
  }

  Widget _cards() {
    return BlocBuilder<VerseCubit, VerseState>(
        builder: (context, state) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await confirmLeaveWhilePlaying(context, state);
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Scaffold(
              backgroundColor: AppColors.bg,
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
                            _modeToggle(),
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
                                  final cubit = context.read<VerseCubit>();
                                  showContinueReadingDialog(
                                    context,
                                    onContinue: () {
                                      if (!mounted) return;
                                      setState(() {
                                        _shouldScrollToSavedPosition = true;
                                      });
                                      cubit.continueFromLastAyah();
                                    },
                                    onRestart: () =>
                                        cubit.resetProgress(widget.suraNumber),
                                  );
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
              floatingActionButton:
                  readerFab(context, state, widget.SuraName),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
            ),
          );
        },
    );
  }
}

