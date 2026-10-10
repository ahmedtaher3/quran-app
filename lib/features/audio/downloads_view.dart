import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/Koran/data/data_sources/local/db_helper.dart';
import 'package:untitled/features/Koran/data/model/sura.dart';
import 'package:untitled/features/audio/audio_downloads.dart';
import 'package:untitled/features/audio/quran_player.dart';

const _teal = Color(0xFF00695C);

class DownloadsView extends StatefulWidget {
  const DownloadsView({super.key});

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView> {
  final dl = AudioDownloads.instance;
  List<Sura> _suras = [];
  Map<int, int> _done = {};
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final suras = await DBHelper.getSuras();
    final reciter = QuranPlayer.instance.reciterId;
    final done = {
      for (final s in suras) s.number: await dl.downloadedCount(reciter, s.number)
    };
    final bytes = await dl.totalBytes();
    if (mounted) {
      setState(() {
        _suras = suras;
        _done = done;
        _bytes = bytes;
      });
    }
  }

  Future<void> _download(Sura s) async {
    try {
      await dl.downloadSura(s.number);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("تعذّر تحميل ${s.name}، تحقق من الإنترنت")));
      }
    }
    _load();
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("حذف كل التنزيلات"),
        content: Text("سيتم حذف ${formatBytes(_bytes)} من الملفات الصوتية."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("تراجع")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await dl.deleteAll();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("التنزيلات",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_bytes > 0)
            IconButton(
              tooltip: "حذف الكل",
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: _suras.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sd_storage_rounded, color: _teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("القارئ: ${QuranPlayer.instance.reciterName}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text("المساحة المستخدمة: ${formatBytes(_bytes)}",
                                style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<Map<int, double>>(
                  valueListenable: dl.progress,
                  builder: (_, prog, __) => Column(
                    children: [for (final s in _suras) _tile(s, prog[s.number])],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(Sura s, double? p) {
    final done = _done[s.number] ?? 0;
    final complete = done >= s.ayahs;
    Widget trailing;
    if (p != null) {
      trailing = IconButton(
        tooltip: "إلغاء",
        onPressed: () => dl.cancel(s.number),
        icon: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(value: p, strokeWidth: 3),
        ),
      );
    } else if (complete) {
      trailing = IconButton(
        tooltip: "حذف",
        icon: const Icon(Icons.check_circle_rounded, color: _teal),
        onPressed: () async {
          await dl.deleteSura(s.number);
          _load();
        },
      );
    } else {
      trailing = IconButton(
        tooltip: "تحميل",
        icon: const Icon(Icons.download_rounded),
        onPressed: () => _download(s),
      );
    }
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.tealSoft,
        child: Text("${s.number}",
            style: const TextStyle(color: _teal, fontSize: 13)),
      ),
      title: Text(s.name),
      subtitle: Text(complete
          ? "محمّلة بالكامل"
          : done > 0
              ? "$done من ${s.ayahs} آية"
              : "${s.ayahs} آية"),
      trailing: trailing,
    );
  }
}

/// Reader app-bar button: download / progress / downloaded for one sura.
class SuraDownloadButton extends StatefulWidget {
  final int sura;
  const SuraDownloadButton({super.key, required this.sura});

  @override
  State<SuraDownloadButton> createState() => _SuraDownloadButtonState();
}

class _SuraDownloadButtonState extends State<SuraDownloadButton> {
  final dl = AudioDownloads.instance;
  bool? _complete;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final total = (await DBHelper.getVersesBySura(widget.sura)).length;
    final done =
        await dl.downloadedCount(QuranPlayer.instance.reciterId, widget.sura);
    if (mounted) setState(() => _complete = done >= total);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<int, double>>(
      valueListenable: dl.progress,
      builder: (_, prog, __) {
        final p = prog[widget.sura];
        if (p != null) {
          return IconButton(
            tooltip: "إلغاء التحميل",
            onPressed: () => dl.cancel(widget.sura),
            icon: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  value: p, strokeWidth: 2.5, color: Colors.white),
            ),
          );
        }
        if (_complete == true) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.offline_pin_rounded, color: Colors.white),
          );
        }
        return IconButton(
          tooltip: "تحميل السورة للاستماع بدون إنترنت",
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          onPressed: () async {
            try {
              await dl.downloadSura(widget.sura);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("تعذّر التحميل، تحقق من الإنترنت")));
              }
            }
            _check();
          },
        );
      },
    );
  }
}
