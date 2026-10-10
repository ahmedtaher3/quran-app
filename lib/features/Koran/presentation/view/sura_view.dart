import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/Koran/data/repo/quran_repository.dart';
import 'package:untitled/features/Koran/presentation/manager/sura_cubit/sura_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/sura_cubit/sura_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/sura_view_deatils.dart';
import 'package:untitled/search_view.dart';
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
                        const SizedBox(height: 10),
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
