import 'package:flutter/material.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/khatma/khatma.dart';
import 'package:untitled/features/stats/stats.dart';

const _teal = Color(0xFF00695C);
const _arDays = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']; // Mon..Sun

class StatsData {
  final int streak, longest, today, verses, pages, suras, khatmas;
  final List<({DateTime day, int verses})> week;
  StatsData(this.streak, this.longest, this.today, this.verses, this.pages,
      this.suras, this.khatmas, this.week);

  static Future<StatsData> load() async {
    final perDay = await DBHelper.versesPerDay();
    final totals = await DBHelper.readTotals();
    final now = DateTime.now();
    final days = perDay.keys.toSet();
    return StatsData(
      currentStreak(days, now),
      longestStreak(days),
      perDay[DBHelper.dayKey(now)] ?? 0,
      totals.verses,
      totals.pages,
      totals.suras,
      await KhatmaStore.completedCount(),
      lastDays(perDay, now, 7),
    );
  }
}

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("إحصائياتي",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<StatsData>(
        future: StatsData.load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data!;
          final list = achievements(
            totalVerses: s.verses,
            suras: s.suras,
            longest: s.longest,
            khatmas: s.khatmas,
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _streakCard(s),
              const SizedBox(height: 16),
              Row(
                children: [
                  _tile("آيات اليوم", "${s.today}", Icons.today_rounded),
                  const SizedBox(width: 12),
                  _tile("أطول سلسلة", "${s.longest} يوم",
                      Icons.trending_up_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tile("آيات مقروءة", "${s.verses}",
                      Icons.format_list_numbered_rtl_rounded),
                  const SizedBox(width: 12),
                  _tile("من المصحف",
                      "${(s.pages / totalPages * 100).toStringAsFixed(1)}%",
                      Icons.pie_chart_rounded),
                ],
              ),
              const SizedBox(height: 20),
              _section("آخر 7 أيام"),
              _weekChart(s.week),
              const SizedBox(height: 20),
              _section("الإنجازات"),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [for (final a in list) _achievement(a)],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _streakCard(StatsData s) {
    final active = s.today > 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? const [Color(0xFFFF8F00), Color(0xFFFFB300)]
              : const [Color(0xFF004D40), Color(0xFF00897B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Colors.white, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${s.streak} يوم",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold)),
                Text(
                  s.streak == 0
                      ? "ابدأ سلسلتك اليوم بقراءة آية"
                      : active
                          ? "سلسلة متواصلة، أحسنت!"
                          : "اقرأ اليوم لتحافظ على سلسلتك",
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _teal),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900)),
      );

  Widget _weekChart(List<({DateTime day, int verses})> week) {
    final maxV = week.fold<int>(1, (m, d) => d.verses > m ? d.verses : m);
    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in week)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(d.verses == 0 ? "" : "${d.verses}",
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Container(
                    width: 18,
                    height: 4 + 80 * d.verses / maxV,
                    decoration: BoxDecoration(
                      color: d.verses == 0
                          ? Colors.teal.shade50
                          : Colors.teal.shade400,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_arDays[d.day.weekday - 1],
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _achievement(Achievement a) {
    final c = a.earned ? const Color(0xFFFFA000) : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: a.earned ? Colors.amber.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: a.earned ? Colors.amber.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(a.icon, color: c, size: 34),
          const SizedBox(height: 6),
          Text(a.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: a.earned ? Colors.black87 : Colors.grey)),
          const SizedBox(height: 2),
          Text(a.hint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
