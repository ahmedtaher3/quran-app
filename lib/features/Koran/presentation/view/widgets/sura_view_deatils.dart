import 'dart:async';

import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:untitled/features/audio/quran_player.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/data/repo/quran_repository.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/verse_card.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/reader_controls.dart';
import 'package:untitled/features/Koran/presentation/view/flow_sura_view.dart';

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

  StreamSubscription<PlayerFailure>? _failures;
  Set<int> _quarterStarts = {}; // ayahs that open a hizb quarter (۞)

  @override
  void initState() {
    super.initState();
    // keep the screen on while reading or listening, in both modes
    WakelockPlus.enable();
    _failures = QuranPlayer.instance.failures.listen(_showFailure);
    DBHelper.quarterStarts(widget.suraNumber).then((s) {
      if (mounted) setState(() => _quarterStarts = s);
    });
  }

  /// Next / previous sura replaces this reader instead of stacking readers.
  void _openSura(Sura s) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) =>
              VerseListView(suraNumber: s.number, SuraName: s.name)),
    );
  }

  Widget _footer() =>
      SuraNavFooter(sura: widget.suraNumber, onOpen: _openSura);

  void _showFailure(PlayerFailure f) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(f.message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: "إعادة المحاولة", onPressed: f.retry),
      ));
  }

  @override
  void dispose() {
    _failures?.cancel();
    WakelockPlus.disable();
    _cubit.close(); // playback itself carries on in the background
    _scrollController.dispose();
    super.dispose();
  }

  // One cubit for both modes: switching keeps playback, bookmarks and the
  // reading position.
  late final _cubit = VerseCubit(QuranRepository())
    ..suraName = widget.SuraName
    ..loadVerses(widget.suraNumber,
        skipContinueDialog: widget.ayaNumber != null);

  bool? _wasFlow;

  /// Ayah number of the saved reading spot, to reopen there after the
  /// reader switches mode.
  int? _spotAya() {
    final s = _cubit.state;
    if (s is! VerseLoaded) return null;
    return s.verses
        .where((v) => v.id == _cubit.lastViewedAyahId)
        .firstOrNull
        ?.ayaNumber;
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppSettings.instance.flowReading;
    final switched = _wasFlow != null && _wasFlow != flow;
    _wasFlow = flow;
    if (switched && !flow) {
      // resume at the spot, not the ayah the screen was first opened at
      _hasScrolledToInitialAyah = true;
      _resumeCardsAtSpot();
    }
    return BlocProvider.value(
      value: _cubit,
      child: flow
          ? FlowSuraView(
              sura: widget.suraNumber,
              suraName: widget.SuraName,
              // only read when the flow view is created, i.e. on a switch
              ayaNumber: (switched ? _spotAya() : null) ?? widget.ayaNumber,
              footer: _footer(),
            )
          : _cards(),
    );
  }

  /// Switched from the flow view: open the cards where the reader was.
  void _resumeCardsAtSpot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = _cubit.state;
      final id = _cubit.lastViewedAyahId;
      if (!mounted || s is! VerseLoaded || id == null) return;
      final index = s.verses.indexWhere((v) => v.id == id);
      if (index == -1) return;
      _scrollToVerse(
          verseId: id, index: index, itemCount: s.verses.length);
      _flashHighlight(id);
    });
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
              appBar: readerAppBar(
                  sura: widget.suraNumber, suraName: widget.SuraName),
              body: Builder(
                builder: (innerContext) {
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
                                        quarterStart: _quarterStarts
                                            .contains(verse.id),
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
                        SliverToBoxAdapter(
                          // clear of the play button / mini player
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 90),
                            child: _footer(),
                          ),
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

