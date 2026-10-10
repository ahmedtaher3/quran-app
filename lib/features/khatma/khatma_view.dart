import 'package:flutter/material.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/Koran/presentation/view/widgets/sura_view_deatils.dart';
import 'package:untitled/features/khatma/khatma.dart';

const _teal = Color(0xFF00695C);

class KhatmaView extends StatefulWidget {
  const KhatmaView({super.key});

  @override
  State<KhatmaView> createState() => _KhatmaViewState();
}

class _KhatmaViewState extends State<KhatmaView> {
  bool _loading = true;
  Khatma? _k;
  int _completed = 0;
  Verse? _from, _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final k = await KhatmaStore.load();
    final completed = await KhatmaStore.completedCount();
    Verse? from, to;
    if (k != null && !k.finished) {
      from = await DBHelper.getPageEdge(k.wirdStart);
      to = await DBHelper.getPageEdge(k.wirdEnd, last: true);
    }
    if (!mounted) return;
    setState(() {
      _k = k;
      _completed = completed;
      _from = from;
      _to = to;
      _loading = false;
    });
  }

  Future<void> _start(int days, TimeOfDay? reminder) async {
    final k = Khatma(
      days: days,
      start: DateTime.now(),
      reminderHour: reminder?.hour,
      reminderMinute: reminder?.minute,
    );
    await KhatmaStore.save(k);
    await _syncReminder(k);
    _load();
  }

  Future<void> _syncReminder(Khatma k) async {
    if (k.reminderHour == null) {
      await Notifications.cancel(Notifications.wirdReminderId);
      return;
    }
    await Notifications.requestPermission();
    await Notifications.scheduleDaily(
      id: Notifications.wirdReminderId,
      hour: k.reminderHour!,
      minute: k.reminderMinute ?? 0,
      title: "وردك اليومي",
      body: "حان وقت ورد القرآن، ${k.dailyPages} صفحات تنتظرك",
    );
  }

  Future<void> _completeWird() async {
    final k = _k!;
    final next = k.copyWith(currentPage: k.wirdEnd + 1);
    if (next.finished) {
      await KhatmaStore.incrementCompleted();
      await KhatmaStore.clear();
      await Notifications.cancel(Notifications.wirdReminderId);
      if (mounted) await _showFinished();
    } else {
      await KhatmaStore.save(next);
    }
    _load();
  }

  Future<void> _showFinished() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("مبارك! أتممت الختمة", textAlign: TextAlign.center),
        content: const Text(
          "اللهم ارحمني بالقرآن واجعله لي إمامًا ونورًا وهدى ورحمة",
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("آمين"),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelKhatma() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("إلغاء الختمة"),
        content: const Text("سيتم حذف تقدمك في هذه الختمة. هل أنت متأكد؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("تراجع")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("إلغاء الختمة",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await KhatmaStore.clear();
    await Notifications.cancel(Notifications.wirdReminderId);
    _load();
  }

  Future<void> _editReminder() async {
    final k = _k!;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: k.reminderHour ?? 20, minute: k.reminderMinute ?? 0),
      helpText: "وقت التذكير",
    );
    if (t == null) return;
    final next = k.copyWith(reminderHour: t.hour, reminderMinute: t.minute);
    await KhatmaStore.save(next);
    await _syncReminder(next);
    _load();
  }

  Future<void> _disableReminder() async {
    final next = _k!.copyWith(clearReminder: true);
    await KhatmaStore.save(next);
    await _syncReminder(next);
    _load();
  }

  void _openWird() {
    final v = _from;
    if (v == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerseListView(
          suraNumber: v.sura,
          SuraName: v.suraName ?? "",
          ayaNumber: v.ayaNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("الختمة والورد اليومي",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_k != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reminder') _editReminder();
                if (v == 'no_reminder') _disableReminder();
                if (v == 'cancel') _cancelKhatma();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'reminder', child: Text("تغيير وقت التذكير")),
                if (_k!.reminderHour != null)
                  const PopupMenuItem(
                      value: 'no_reminder', child: Text("إيقاف التذكير")),
                const PopupMenuItem(
                    value: 'cancel',
                    child: Text("إلغاء الختمة",
                        style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _k == null
              ? _Setup(completed: _completed, onStart: _start)
              : _active(_k!),
    );
  }

  Widget _active(Khatma k) {
    final now = DateTime.now();
    final behind = k.pagesBehind(now);
    final status = behind > 0
        ? "متأخر $behind صفحة عن الخطة"
        : behind < 0
            ? "متقدم ${-behind} صفحة عن الخطة"
            : "على الخطة تمامًا";
    final statusColor = behind > 0 ? Colors.orange.shade800 : _teal;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // progress
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00897B)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: k.progress,
                      strokeWidth: 10,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                    ),
                    Center(
                      child: Text(
                        "${(k.progress * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ختمة في ${k.days} يوم",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _whiteLine("اليوم ${k.dayNumber(now)} من ${k.days}"),
                    _whiteLine("${k.pagesDone} من $totalPages صفحة"),
                    _whiteLine("متبقي ${k.daysLeft(now)} يوم"),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(status,
              style: TextStyle(
                  color: statusColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),

        // today's wird
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.today_rounded, color: _teal),
                  const SizedBox(width: 8),
                  Text(k.doneToday(now) ? "الورد التالي" : "ورد اليوم",
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _teal)),
                  const Spacer(),
                  Text(
                    "صفحة ${k.wirdStart} - ${k.wirdEnd}",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (k.doneToday(now))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text("أنهيت ورد اليوم، بارك الله فيك",
                      style: TextStyle(color: Colors.green.shade700)),
                ),
              const SizedBox(height: 16),
              _edge("من", _from),
              const SizedBox(height: 8),
              _edge("إلى", _to),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openWird,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text("ابدأ القراءة"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _completeWird,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text("أتممت ورد اليوم"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  minimumSize: const Size(0, 52),
                  side: const BorderSide(color: _teal),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.notifications_active_rounded,
              color: _teal),
          title: Text(k.reminderHour == null
              ? "بدون تذكير يومي"
              : "تذكير يومي الساعة ${TimeOfDay(hour: k.reminderHour!, minute: k.reminderMinute ?? 0).format(context)}"),
          trailing: const Icon(Icons.edit_rounded, size: 18),
          onTap: _editReminder,
        ),
        if (_completed > 0)
          ListTile(
            leading: const Icon(Icons.emoji_events_rounded,
                color: Color(0xFFFFB300)),
            title: Text("ختمات مكتملة: $_completed"),
          ),
      ],
    );
  }

  Widget _whiteLine(String t) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(t, style: const TextStyle(color: Colors.white70)),
      );

  Widget _edge(String label, Verse? v) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: TextStyle(color: Colors.grey.shade500)),
        ),
        Expanded(
          child: Text(
            v == null ? "..." : "${v.suraName ?? ''} • آية ${v.ayaNumber}",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _Setup extends StatefulWidget {
  final int completed;
  final Future<void> Function(int days, TimeOfDay? reminder) onStart;
  const _Setup({required this.completed, required this.onStart});

  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  static const _presets = [7, 10, 15, 30, 60, 90];
  int _days = 30;
  TimeOfDay? _reminder = const TimeOfDay(hour: 20, minute: 0);
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final pages = (totalPages / _days).ceil();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.auto_stories_rounded, size: 72, color: Colors.teal.shade200),
        const SizedBox(height: 12),
        const Text(
          "ابدأ ختمة جديدة",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: _teal),
        ),
        const SizedBox(height: 6),
        Text(
          "اختر المدة، وسنقسم لك المصحف وردًا يوميًا",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        if (widget.completed > 0) ...[
          const SizedBox(height: 8),
          Text("أتممت ${widget.completed} ختمة من قبل",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFA000))),
        ],
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final d in _presets)
              ChoiceChip(
                label: Text("$d يوم"),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Slider(
          value: _days.toDouble(),
          min: 3,
          max: 365,
          divisions: 362,
          label: "$_days يوم",
          onChanged: (v) => setState(() => _days = v.round()),
        ),
        Center(
          child: Text(
            "$pages صفحة يوميًا تقريبًا",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          value: _reminder != null,
          onChanged: (on) => setState(() =>
              _reminder = on ? const TimeOfDay(hour: 20, minute: 0) : null),
          title: const Text("تذكير يومي"),
          subtitle: _reminder == null ? null : Text(_reminder!.format(context)),
          secondary: const Icon(Icons.alarm_rounded, color: _teal),
        ),
        if (_reminder != null)
          TextButton(
            onPressed: () async {
              final t = await showTimePicker(
                  context: context, initialTime: _reminder!);
              if (t != null) setState(() => _reminder = t);
            },
            child: const Text("تغيير الوقت"),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await widget.onStart(_days, _reminder);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 54),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("ابدأ الختمة",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
