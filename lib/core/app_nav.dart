import 'package:flutter/widgets.dart';

/// Root navigator, so a notification (or home-screen widget) tap can open
/// a screen without a BuildContext.
final appNavigatorKey = GlobalKey<NavigatorState>();
