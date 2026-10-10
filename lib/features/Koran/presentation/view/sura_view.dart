import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/data/repo/quran_repository.dart';
import 'package:untitled/features/Koran/presentation/manager/sura_cubit/sura_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/sura_cubit/sura_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/sura_view_deatils.dart';
import 'package:untitled/search_view.dart';
import 'package:untitled/features/khatma/khatma.dart';
import 'package:untitled/features/stats/stats.dart';
import 'package:untitled/features/stats/stats_view.dart';
import 'package:untitled/features/hifz/hifz_view.dart';
import 'package:untitled/features/quiz/quiz_view.dart';
import 'package:untitled/features/recite/recite_view.dart';
import 'package:untitled/features/audio/downloads_view.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/khatma/khatma_view.dart';
import 'package:untitled/features/Koran/presentation/view/bookmarks_view.dart';

class SuraView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SuraCubit(QuranRepository())..loadSuras(),
      child: Builder(
        builder: (builderContext) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FBF9),
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 150.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF00695C),
                  actions: [
                    const _StreakAction(),
                    IconButton(
                      tooltip: "العلامات",
                      icon: const Icon(Icons.bookmarks_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BookmarksView()),
                      ).then((_) => builderContext
                          .read<SuraCubit>()
                          .refreshLastRead()),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: const Text(
                      "سور القرآن",
                      style: TextStyle(
                        
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF004D40), Color(0xFF00796B)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -20,
                            right: -20,
                            child: Icon(
                              Icons.mosque,
                              size: 150,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 10),
                    child: Column(
                      children: [
                        // Search Bar - NOW WRAPPED CAREFULLY
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SearchScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: Colors.teal.shade50),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search,
                                      color: Colors.teal.shade700),
                                  const SizedBox(width: 12),
                                  Text(
                                    "ابحث في السور والآيات...",
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _LastReadWidget(),
                        const SizedBox(height: 12),
                        const _KhatmaCard(),
                        const SizedBox(height: 12),
                        const _QuickActions(),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "فهرس السور",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                BlocBuilder<SuraCubit, SuraState>(
                  builder: (context, state) {
                    if (state is SuraLoading) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (state is SuraLoaded) {
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final s = state.suras[index];
                            return SuraItemCard(sura: s);
                          },
                          childCount: state.suras.length,
                        ),
                      );
                    }
                    return const SliverToBoxAdapter(child: SizedBox());
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LastReadWidget extends StatelessWidget {
  const _LastReadWidget();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SuraCubit, SuraState>(
      builder: (context, state) {
        if (state is! SuraLoaded || state.lastReadSura == null) {
          return const SizedBox();
        }

        final lastSuraNum = state.lastReadSura!;
        final lastAya = state.lastReadAya;
        String suraName = "سورة رقم $lastSuraNum";

        try {
          final sura = state.suras.firstWhere((s) => s.number == lastSuraNum);
          suraName = sura.name;
        } catch (_) {}

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF00897B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    bottom: -30,
                    child: Icon(
                      Icons.auto_stories,
                      size: 120,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.menu_book_rounded,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "متابعة القراءة",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                suraName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  
                                ),
                              ),
                              if (lastAya != null)
                                Text(
                                  "الآية $lastAya",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VerseListView(
                                    suraNumber: lastSuraNum,
                                    SuraName: suraName,
                                    ayaNumber: lastAya,
                                  ),
                                ),
                              ).then((_) {
                                // تحديث البيانات فور العودة من القراءة
                                context.read<SuraCubit>().refreshLastRead();
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Text(
                                "استمر",
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    void go(Widget page) => Navigator.push(
            context, MaterialPageRoute(builder: (_) => page))
        .then((_) {
      if (context.mounted) context.read<SuraCubit>().refreshLastRead();
    });
    final items = <(IconData, String, Color, Widget)>[
      (Icons.psychology_rounded, "الحفظ", Colors.indigo, const HifzView()),
      (Icons.quiz_rounded, "اختبار", Colors.purple, const QuizView()),
      (Icons.mic_rounded, "تسميع", Colors.red.shade400, const ReciteStartView()),
      (Icons.insights_rounded, "إحصائياتي", Colors.orange.shade800,
          const StatsView()),
      (Icons.bookmarks_rounded, "العلامات", Colors.teal, const BookmarksView()),
      (Icons.download_for_offline_rounded, "التنزيلات", Colors.blueGrey,
          const DownloadsView()),
    ];
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (icon, label, color, page) in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => go(page),
                child: Container(
                  width: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withOpacity(0.15)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(height: 6),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakAction extends StatefulWidget {
  const _StreakAction();

  @override
  State<_StreakAction> createState() => _StreakActionState();
}

class _StreakActionState extends State<_StreakAction> {
  int? _streak;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = (await DBHelper.versesPerDay()).keys.toSet();
    if (mounted) setState(() => _streak = currentStreak(days, DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    // SuraCubit re-emits whenever we come back from reading
    return BlocListener<SuraCubit, SuraState>(
      listener: (_, __) => _load(),
      child: TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StatsView()),
        ).then((_) => _load()),
        icon: const Icon(Icons.local_fire_department_rounded,
            color: Color(0xFFFFB300)),
        label: Text("${_streak ?? 0}",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _KhatmaCard extends StatefulWidget {
  const _KhatmaCard();

  @override
  State<_KhatmaCard> createState() => _KhatmaCardState();
}

class _KhatmaCardState extends State<_KhatmaCard> {
  late Future<Khatma?> _k = KhatmaStore.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Khatma?>(
      future: _k,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 72);
        }
        final k = snap.data;
        final title = k == null
            ? "ابدأ ختمة جديدة"
            : k.doneToday(DateTime.now())
                ? "أنهيت ورد اليوم ✓"
                : "ورد اليوم";
        final subtitle = k == null
            ? "قسّم المصحف على أيام مع تذكير يومي"
            : "صفحة ${k.wirdStart} - ${k.wirdEnd} • ${(k.progress * 100).toStringAsFixed(0)}% من الختمة";
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KhatmaView()),
              ).then((_) {
                if (!mounted) return;
                setState(() => _k = KhatmaStore.load());
                context.read<SuraCubit>().refreshLastRead();
              }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.track_changes_rounded,
                          color: Colors.amber.shade800),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    if (k != null)
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          value: k.progress,
                          strokeWidth: 4,
                          backgroundColor: Colors.amber.shade50,
                          valueColor: AlwaysStoppedAnimation(
                              Colors.amber.shade700),
                        ),
                      )
                    else
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.grey.shade300),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SuraItemCard extends StatelessWidget {
  final Sura sura;
  const SuraItemCard({super.key, required this.sura});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VerseListView(suraNumber: sura.number, SuraName: sura.name),
            ),
          ).then((_) {
            if (context.mounted) context.read<SuraCubit>().refreshLastRead();
          }),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Number Badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.brightness_7_rounded,
                      size: 50,
                      color: Colors.teal.shade50.withOpacity(0.5),
                    ),
                    Text(
                      sura.number.toString(),
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sura.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "${sura.revelationType == 'Meccan' ? 'مكية' : 'مدنية'} • ${sura.ayahs} آية",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
