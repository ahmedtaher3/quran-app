import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/repo/quran_repository.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/verse_card.dart';

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
          VerseCubit(QuranRepository())..loadVerses(widget.suraNumber,
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
              floatingActionButton: state is VerseLoaded
                  ? _PlayAllButton(
                      isPlaying: state.playingAyahId != null,
                      onTap: () {
                        if (state.playingAyahId != null) {
                          context.read<VerseCubit>().stopSequentialPlay();
                        } else {
                          context.read<VerseCubit>().startSequentialPlay();
                        }
                      },
                    )
                  : null,
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
