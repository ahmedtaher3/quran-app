import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:untitled/features/Koran/data/model/ayah.dart';
import 'package:untitled/features/audio/quran_player.dart';

const _teal = Color(0xFF00695C);

/// Controls for the shared [QuranPlayer]: whatever is playing right now.
void showPlayerSheet(BuildContext context, {VoidCallback? onPlaySequential}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PlayerSheet(onPlaySequential: onPlaySequential),
  );
}

class PlayerSheet extends StatefulWidget {
  final VoidCallback? onPlaySequential;
  const PlayerSheet({super.key, this.onPlaySequential});

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  final qp = QuranPlayer.instance;
  AudioPlayer get p => qp.player;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const _repeats = [1, 2, 3, 5, 10];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              StreamBuilder<Verse?>(
                stream: qp.currentVerse,
                initialData: qp.current,
                builder: (_, snap) {
                  final v = snap.data ?? qp.current;
                  return Column(
                    children: [
                      Text(
                        v == null
                            ? "ترتيل الآية الكريمة"
                            : "${v.suraName ?? qp.suraName ?? 'سورة ${v.sura}'} - آية ${v.ayaNumber}",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(qp.reciterName,
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _progress(),
              const SizedBox(height: 8),
              _controls(),
              const SizedBox(height: 20),
              _label("سرعة التلاوة"),
              _chips<double>(
                _speeds,
                qp.speed,
                (s) => "${s}x",
                (s) async {
                  await qp.setSpeed(s);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              _label("تكرار كل آية"),
              _chips<int>(
                _repeats,
                qp.repeatEach,
                (n) => n == 1 ? "مرة" : "$n مرات",
                (n) async {
                  await qp.setRepeatEach(n);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: qp.loopRange,
                onChanged: (on) async {
                  await qp.setLoopRange(on);
                  setState(() {});
                },
                title: const Text("تكرار المقطع كاملًا"),
                subtitle: const Text("إعادة التشغيل من البداية عند الانتهاء"),
                secondary: const Icon(Icons.repeat_rounded, color: _teal),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over_rounded,
                    color: _teal),
                title: const Text("القارئ"),
                subtitle: Text(qp.reciterName),
                trailing: const Icon(Icons.chevron_right_rounded), // mirrored in RTL
                onTap: _pickReciter,
              ),
              if (widget.onPlaySequential != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onPlaySequential!();
                    },
                    icon: const Icon(Icons.playlist_play_rounded),
                    label: const Text("تشغيل متتابع من هذه الآية",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade50,
                      foregroundColor: _teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    return StreamBuilder<Duration>(
      stream: p.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = p.duration ?? Duration.zero;
        final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        return Column(
          children: [
            Slider(
              value: pos.inMilliseconds.toDouble().clamp(0, max),
              max: max,
              activeColor: _teal,
              inactiveColor: Colors.teal.shade50,
              onChanged: (v) => p.seek(Duration(milliseconds: v.toInt())),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_time(pos), _time(dur)],
            ),
          ],
        );
      },
    );
  }

  Widget _controls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // RTL: "next ayah" sits on the left
        _round(Icons.skip_next_rounded, qp.previous, tooltip: "الآية السابقة"),
        const SizedBox(width: 24),
        StreamBuilder<PlayerState>(
          stream: p.playerStateStream,
          builder: (_, snap) {
            final st = snap.data;
            final loading = st?.processingState == ProcessingState.loading ||
                st?.processingState == ProcessingState.buffering;
            final playing = st?.playing ?? false;
            return Container(
              width: 76,
              height: 76,
              decoration:
                  const BoxDecoration(color: _teal, shape: BoxShape.circle),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    )
                  : IconButton(
                      icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 44,
                          color: Colors.white),
                      onPressed: () {
                        if (playing) {
                          p.pause();
                        } else {
                          if (st?.processingState ==
                              ProcessingState.completed) {
                            p.seek(Duration.zero, index: 0);
                          }
                          p.play();
                        }
                      },
                    ),
            );
          },
        ),
        const SizedBox(width: 24),
        _round(Icons.skip_previous_rounded, qp.next, tooltip: "الآية التالية"),
      ],
    );
  }

  Future<void> _pickReciter() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in reciters)
              RadioListTile<String>(
                value: r.id,
                groupValue: qp.reciterId,
                onChanged: (v) => Navigator.pop(context, v),
                title: Text(r.name),
                activeColor: _teal,
              ),
          ],
        ),
      ),
    );
    if (id == null) return;
    await qp.setReciter(id);
    if (mounted) setState(() {});
  }

  Widget _label(String t) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(t,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
        ),
      );

  Widget _chips<T>(List<T> values, T selected, String Function(T) label,
      void Function(T) onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onTap(v),
            selectedColor: Colors.teal.shade100,
          ),
      ],
    );
  }

  Widget _round(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return Container(
      decoration:
          BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: _teal, size: 30),
        onPressed: onTap,
      ),
    );
  }

  Widget _time(Duration d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return Text("${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}",
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12));
  }
}
