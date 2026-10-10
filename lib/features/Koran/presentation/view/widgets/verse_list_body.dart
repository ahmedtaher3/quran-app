import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_cubit.dart';
import 'package:untitled/features/Koran/presentation/manager/cubit/verse_state.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/verse_card.dart';

class VerseListBody extends StatelessWidget {
  final ScrollController scrollController;
  final GlobalKey Function(int) ayahKeyFor;
  final int? highlightVerseId;
  final int suraNumber;

  const VerseListBody({
    super.key,
    required this.scrollController,
    required this.ayahKeyFor,
    required this.suraNumber,
    this.highlightVerseId,
  });

  /// 🔥 دالة الحصول على الآية الموجودة في منتصف الشاشة
  int? _getMiddleAyahId(List verses) {
    try {
      final screenHeight = WidgetsBinding
              .instance.platformDispatcher.views.first.physicalSize.height /
          WidgetsBinding
              .instance.platformDispatcher.views.first.devicePixelRatio;

      final middleY = screenHeight / 2;

      for (var v in verses) {
        final key = ayahKeyFor(v.id);
        final ctx = key.currentContext;
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VerseCubit, VerseState>(
      builder: (context, state) {
        if (state is VerseLoading) {
          return Center(child: CircularProgressIndicator());
        }
        if (state is VerseError) {
          return Center(child: Text("خطأ: ${state.message}"));
        }
        if (state is VerseLoaded) {
          final verses = state.verses;
          final highlightedAyahId = state.lastViewedAyahId;

          return NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              final midAyah = _getMiddleAyahId(verses);
              if (midAyah != null) {
                context.read<VerseCubit>().updateReadingPosition(
                      suraNumber,
                      midAyah,
                    );
              }
              return true;
            },
            child: ListView.builder(
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
              controller: scrollController,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              itemCount: verses.length,
              itemBuilder: (context, index) {
                var verse = verses[index];
                final key = ayahKeyFor(verse.id);

                return VerseCard(
                  key: key,
                  verse: verse,
                  highlight: verse.id == highlightedAyahId ||
                      verse.id == highlightVerseId,
                );
              },
            ),
          );
        }
        return SizedBox();
      },
    );
  }
}
