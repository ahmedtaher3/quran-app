import 'package:flutter/material.dart';
import 'package:untitled/core/app_nav.dart';
import 'package:untitled/core/notifications.dart';
import 'package:untitled/features/prayer/prayer_view.dart';

/// Opens the prayer screen from outside the app (adhan notification now,
/// the home-screen widget later). A request that arrives while the loading
/// screen is still up waits until the home screen exists.
class PrayerLaunch {
  static bool pending = false;
  static bool _homeReady = false;

  static void handlePayload(String? payload) {
    if (payload == Notifications.prayerPayload) open();
  }

  static void open() {
    final nav = appNavigatorKey.currentState;
    if (!_homeReady || nav == null) {
      pending = true;
      return;
    }
    _push(nav);
  }

  /// Called by the loading screen right after it shows the home screen.
  static void homeReady() {
    _homeReady = true;
    final nav = appNavigatorKey.currentState;
    if (pending && nav != null) {
      pending = false;
      _push(nav);
    }
  }

  static void _push(NavigatorState nav) {
    // a second tap must not stack another prayer screen on the first
    var onTop = false;
    nav.popUntil((r) {
      onTop = r.settings.name == PrayerView.routeName;
      return true;
    });
    if (onTop) return;
    nav.push(MaterialPageRoute(
      settings: const RouteSettings(name: PrayerView.routeName),
      builder: (_) => const PrayerView(),
    ));
  }
}
