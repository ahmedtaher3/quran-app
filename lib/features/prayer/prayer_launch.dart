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
    // already open (from the home tile or an earlier tap): bring it forward,
    // closing a sheet or dialog above it, instead of stacking a second one
    final open = PrayerView.openRoute;
    if (open != null && open.isActive) {
      nav.popUntil((r) => r == open);
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => const PrayerView()));
  }
}
