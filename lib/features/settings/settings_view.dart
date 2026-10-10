import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';

const _teal = Color(0xFF00695C);
const _sample = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text("المظهر والخط",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: _teal,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Text(_sample,
                  textAlign: TextAlign.center, style: s.quranStyle()),
            ),
            const SizedBox(height: 24),
            _label("الوضع"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (t, name, icon) in [
                  (ThemeChoice.system, "تلقائي", Icons.brightness_auto_rounded),
                  (ThemeChoice.light, "فاتح", Icons.light_mode_rounded),
                  (ThemeChoice.dark, "ليلي", Icons.dark_mode_rounded),
                  (ThemeChoice.sepia, "ورقي", Icons.menu_book_rounded),
                ])
                  ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(name),
                    selected: s.theme == t,
                    onSelected: (_) => s.update(theme: t),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _label("خط المصحف"),
            for (final e in AppSettings.fonts.entries)
              RadioListTile<String>(
                value: e.key,
                groupValue: s.quranFont,
                onChanged: (v) => s.update(quranFont: v),
                title: Text(e.value),
                subtitle: Text("ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ",
                    style: TextStyle(fontFamily: e.key, fontSize: 20)),
              ),
            const SizedBox(height: 16),
            _label("حجم الخط: ${s.quranSize.round()}"),
            Slider(
              value: s.quranSize,
              min: 18,
              max: 44,
              divisions: 13,
              label: "${s.quranSize.round()}",
              onChanged: (v) => s.update(quranSize: v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.subtle)),
      );
}
