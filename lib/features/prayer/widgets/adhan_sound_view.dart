import 'dart:async';

import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/audio/audio_downloads.dart' show formatBytes;
import 'package:untitled/features/prayer/adhan_sound/adhan_catalog.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_sound_prefs.dart';
import 'package:untitled/features/prayer/adhan_sound/adhan_sound_store.dart';
import 'package:untitled/features/prayer/widgets/settings_group.dart';

/// Picks the adhan sound: the default tone, a file from the phone, or a
/// catalog voice (downloaded once, then it works offline). Fajr can have
/// its own.
class AdhanSoundView extends StatefulWidget {
  final bool startFajr;
  const AdhanSoundView({super.key, this.startFajr = false});

  @override
  State<AdhanSoundView> createState() => _AdhanSoundViewState();
}

class _AdhanSoundViewState extends State<AdhanSoundView> {
  final store = AdhanSoundStore.instance;
  late bool fajr = widget.startFajr;
  late final StreamSubscription<String> _messages;

  @override
  void initState() {
    super.initState();
    store.open();
    _messages = store.messages.stream.listen(_show);
  }

  @override
  void dispose() {
    _messages.cancel();
    store.stopPreview();
    super.dispose();
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<String?> action) async {
    final msg = await action;
    if (msg != null) _show(msg);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final choice = store.sounds.choiceFor(fajr: fajr);
        final fileKey = 'file_${fajr ? 'fajr' : 'all'}';
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: const Text('صوت الأذان'),
            backgroundColor: AppColors.bg,
            foregroundColor: AppColors.text,
            surfaceTintColor: Colors.transparent,
          ),
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 120 + bottom),
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('كل الصلوات')),
                      ButtonSegment(value: true, label: Text('الفجر')),
                    ],
                    selected: {fajr},
                    onSelectionChanged: (v) {
                      store.stopPreview();
                      setState(() => fajr = v.first);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                    child: Text(
                      fajr
                          ? 'أذان الفجر فيه «الصلاة خير من النوم»، فيمكنك اختيار صوت خاص به.'
                          : 'الصوت الذي يُرفع به الأذان عند دخول وقت كل صلاة.',
                      style: TextStyle(fontSize: 13, color: AppColors.subtle),
                    ),
                  ),
                  const SettingsTitle('على هاتفك'),
                  SettingsGroup(children: [
                    if (fajr)
                      _ChoiceTile(
                        icon: Icons.repeat_rounded,
                        title: 'نفس صوت الأذان',
                        subtitle: store.sounds.labelFor(fajr: false),
                        selected: choice.kind == SoundKind.same,
                        onTap: () => _run(store.selectSame()),
                      ),
                    _ChoiceTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'نغمة الإشعار الافتراضية',
                      subtitle: 'نغمة الهاتف المعتادة',
                      selected: choice.kind == SoundKind.system,
                      onTap: () => _run(store.selectSystem(fajr: fajr)),
                    ),
                    _ChoiceTile(
                      icon: Icons.folder_open_rounded,
                      title: 'ملف من هاتفك',
                      subtitle: choice.kind == SoundKind.file
                          ? choice.label ?? ''
                          : 'اختر أي ملف صوتي لديك',
                      selected: choice.kind == SoundKind.file,
                      onTap: () => _run(store.pickFile(fajr: fajr)),
                      previewing: store.previewing == fileKey,
                      onPreview: choice.kind == SoundKind.file && choice.path != null
                          ? () => store.togglePreview(fileKey, choice.label ?? '', choice.path!)
                          : null,
                    ),
                  ]),
                  const SettingsTitle('أصوات تُحمَّل مرة واحدة'),
                  SettingsGroup(children: _catalogRows(context)),
                  if (store.catalog.isNotEmpty)
                    Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Text(
                      'اضغط على أي صوت ليُحمَّل مرة واحدة ويصبح صوت الأذان، ثم يعمل دون إنترنت. '
                      'زر التشغيل يُسمعك عيّنة أولًا.',
                      style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.subtle),
                    ),
                  ),
                ],
              ),
              if (store.previewing != null)
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 16 + bottom,
                  child: _PreviewBar(store: store),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _catalogRows(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    if (store.catalog.isEmpty) {
      if (store.catalogLoading) {
        return const [
          ListTile(
            leading: SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('جارٍ تحميل قائمة الأصوات…'),
          ),
        ];
      }
      if (store.catalogFailed) {
        return [
          ListTile(
            leading: Icon(Icons.cloud_off_rounded, color: primary),
            title: const Text('تعذّر تحميل قائمة الأصوات'),
            subtitle: const Text('تأكد من الاتصال بالإنترنت وحاول مجددًا'),
            trailing: TextButton(
                onPressed: store.refreshCatalog, child: const Text('إعادة المحاولة')),
          ),
        ];
      }
      return [
        ListTile(
          leading: Icon(Icons.schedule_rounded, color: primary),
          title: const Text('أصوات المؤذنين قريبًا'),
          subtitle: const Text('تُضاف هنا دون تحديث التطبيق'),
        ),
      ];
    }
    return [
      for (final it in store.catalog)
        _CatalogTile(
          item: it,
          fajr: fajr,
          store: store,
          onSelect: () => _run(store.selectCatalog(it, fajr: fajr)),
        ),
    ];
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPreview;
  final bool previewing;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onPreview,
    this.previewing = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      selected: selected,
      selectedTileColor: primary.withValues(alpha: 0.06),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.tealSoft,
        child: Icon(icon, color: primary, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              color: AppColors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: selected ? primary : AppColors.subtle)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (onPreview != null)
          IconButton(
            tooltip: previewing ? 'إيقاف العيّنة' : 'تشغيل عيّنة',
            onPressed: onPreview,
            icon: Icon(previewing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: primary),
          ),
        _Mark(selected: selected),
      ]),
      onTap: onTap,
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final AdhanCatalogItem item;
  final bool fajr;
  final AdhanSoundStore store;
  final VoidCallback onSelect;

  const _CatalogTile(
      {required this.item, required this.fajr, required this.store, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final key = store.rowKey(item, fajr: fajr);
    final progress = store.progressOf(item, fajr: fajr);
    final selected = store.isSelected(item, fajr: fajr);
    final playing = store.previewing == key;
    final size = item.sizeFor(fajr: fajr);
    final sub = [
      item.place,
      if (item.seconds > 0) item.duration,
      if (fajr && item.hasFajr) 'نسخة الفجر',
    ].where((s) => s.isNotEmpty).join(' · ');

    final Widget trailing;
    if (progress != null) {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${(progress * 100).round()}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(value: progress == 0 ? null : progress, strokeWidth: 3),
        ),
      ]);
    } else if (store.isDownloaded(item, fajr: fajr)) {
      trailing = _Mark(selected: selected);
    } else {
      trailing = Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.download_rounded, size: 16, color: primary),
          const SizedBox(width: 6),
          Text(size > 0 ? formatBytes(size) : 'تحميل',
              textDirection: size > 0 ? TextDirection.ltr : null,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
        ]),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 16),
      selected: selected,
      selectedTileColor: primary.withValues(alpha: 0.06),
      leading: IconButton(
        tooltip: playing ? 'إيقاف العيّنة' : 'تشغيل عيّنة من ${item.name}',
        onPressed: () => store.togglePreview(
            key, item.name, store.previewSourceFor(item, fajr: fajr)),
        icon: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.tealSoft,
          child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: primary),
        ),
      ),
      title: Text(item.name,
          style: TextStyle(
              color: selected ? AppColors.heading : AppColors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: sub.isEmpty && item.credit == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sub.isNotEmpty) Text(sub, style: TextStyle(color: AppColors.subtle)),
                if (item.credit != null)
                  Text(item.credit!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.subtle)),
              ],
            ),
      isThreeLine: sub.isNotEmpty && item.credit != null,
      trailing: trailing,
      onTap: onSelect,
    );
  }
}

/// The selection mark: a filled check, or an empty ring.
class _Mark extends StatelessWidget {
  final bool selected;
  const _Mark({required this.selected});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: 16, color: Theme.of(context).colorScheme.onPrimary),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.subtle, width: 2),
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  final AdhanSoundStore store;
  const _PreviewBar({required this.store});

  static const _bg = Color(0xFF004D40);
  static const _soft = Color(0xFFB2DFDB);

  @override
  Widget build(BuildContext context) {
    final secs = store.previewPos.floor().toString().padLeft(2, '0');
    return Material(
      color: _bg,
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('عيّنة', style: TextStyle(fontSize: 12, color: _soft)),
                Text(store.previewName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
            Text(
                store.previewLoading
                    ? 'جارٍ التحميل…'
                    : '0:$secs / 0:${AdhanSoundStore.previewSeconds}',
                textDirection: store.previewLoading ? null : TextDirection.ltr,
                style: const TextStyle(fontSize: 13, color: _soft)),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'إيقاف العيّنة',
              style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _bg),
              onPressed: store.stopPreview,
              icon: const Icon(Icons.stop_rounded),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: store.previewLoading
                  ? null
                  : store.previewPos / AdhanSoundStore.previewSeconds,
              minHeight: 4,
              backgroundColor: const Color(0xFF2E6E64),
              color: const Color(0xFF80CBC4),
            ),
          ),
        ]),
      ),
    );
  }
}
