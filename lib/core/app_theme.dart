import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeChoice { system, light, dark, sepia }

class _Palette {
  final Color bg, surface, text, subtle;
  const _Palette(this.bg, this.surface, this.text, this.subtle);
}

const _light = _Palette(
    Color(0xFFF9FBF9), Colors.white, Color(0xDD000000), Color(0xFF757575));
const _dark = _Palette(
    Color(0xFF0E1716), Color(0xFF1A2725), Color(0xFFE8EFEE), Color(0xFF9DB0AD));
const _sepia = _Palette(
    Color(0xFFF3EAD7), Color(0xFFFBF5E8), Color(0xFF3B2E1E), Color(0xFF7A6A55));

/// App-wide look + reader preferences. The whole app rebuilds when this
/// changes (MaterialApp listens), so plain static getters stay in sync.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  ThemeChoice theme = ThemeChoice.system;
  String quranFont = 'Hafs';
  double quranSize = 26;
  bool flowReading = false; // mushaf-style continuous text vs ayah cards

  static const fonts = {'Hafs': 'حفص', 'Majeed': 'المجيد', 'Nabi': 'نبي'};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    theme = ThemeChoice.values.byName(p.getString('theme') ?? 'system');
    quranFont = p.getString('quran_font') ?? 'Hafs';
    quranSize = p.getDouble('quran_size') ?? 26;
    flowReading = p.getBool('flow_reading') ?? false;
  }

  Future<void> update(
      {ThemeChoice? theme,
      String? quranFont,
      double? quranSize,
      bool? flowReading}) async {
    this.flowReading = flowReading ?? this.flowReading;
    this.theme = theme ?? this.theme;
    this.quranFont = quranFont ?? this.quranFont;
    this.quranSize = quranSize ?? this.quranSize;
    notifyListeners();
    _rebuildAll();
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', this.theme.name);
    await p.setString('quran_font', this.quranFont);
    await p.setDouble('quran_size', this.quranSize);
    await p.setBool('flow_reading', this.flowReading);
  }

  /// Called when the OS switches light/dark while on "system".
  void platformChanged() {
    if (theme != ThemeChoice.system) return;
    notifyListeners();
    _rebuildAll();
  }

  // ponytail: screens read colors from static getters instead of
  // Theme.of(context) (~100 call sites), so mark every element dirty the
  // way hot reload does. Keeps navigation and state; fine for a rare action.
  void _rebuildAll() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }

  bool get isDark =>
      theme == ThemeChoice.dark ||
      (theme == ThemeChoice.system &&
          PlatformDispatcher.instance.platformBrightness == Brightness.dark);

  _Palette get _p => isDark
      ? _dark
      : theme == ThemeChoice.sepia
          ? _sepia
          : _light;

  TextStyle quranStyle({double scale = 1, Color? color}) => TextStyle(
        fontFamily: quranFont,
        fontSize: quranSize * scale,
        height: 2.0,
        color: color ?? AppColors.text,
      );

  ThemeData get themeData {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00695C),
      secondary: const Color(0xFFFFB300),
      surface: _p.surface,
      onSurface: _p.text,
    );
    return ThemeData(
      colorScheme: base,
      useMaterial3: true,
      fontFamily: 'Nabi',
      scaffoldBackgroundColor: _p.bg,
      cardColor: _p.surface,
      canvasColor: _p.surface,
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: _p.surface),
      dialogTheme: DialogThemeData(backgroundColor: _p.surface),
    );
  }
}

/// Surface colors that follow the current theme.
class AppColors {
  static _Palette get _p => AppSettings.instance._p;
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get text => _p.text;
  static Color get subtle => _p.subtle;
  static bool get _dark => AppSettings.instance.isDark;
  /// Section headings (teal 900 on light is invisible on dark).
  static Color get heading =>
      _dark ? const Color(0xFF80CBC4) : const Color(0xFF004D40);
  /// Soft tinted fills used behind icons/chips.
  static Color get tealSoft =>
      _dark ? const Color(0xFF1F3A36) : const Color(0xFFE0F2F1);
  static Color get amberSoft =>
      _dark ? const Color(0xFF3A3220) : const Color(0xFFFFF8E1);
}
