import 'package:flutter/widgets.dart';

/// "4:58 م", kept in that order inside Arabic text. TimeOfDay.format in
/// Arabic lets the bidi algorithm split the digits ("58: 4م"); an LTR
/// isolate around "h:mm" keeps them together. Honors the 24-hour setting.
String prayerTime(BuildContext context, DateTime t) {
  final mm = t.minute.toString().padLeft(2, '0');
  if (MediaQuery.alwaysUse24HourFormatOf(context)) {
    return '\u2066${t.hour.toString().padLeft(2, '0')}:$mm\u2069';
  }
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '\u2066$h:$mm\u2069 ${t.hour < 12 ? 'ص' : 'م'}';
}
