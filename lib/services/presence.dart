import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'api.dart';

/// Reports this device's presence + telemetry (battery, model, app version,
/// current screen, GPS) to the backend so managers/heads can monitor the
/// sales team's phones. Activity-driven only — fired on login, app resume,
/// and screen changes. There is deliberately no background timer, so the
/// device naturally falls "offline" once it stops reporting (the dashboard
/// applies a freshness threshold).
class PresenceService {
  PresenceService._();
  static final instance = PresenceService._();

  ApiClient? _api;
  final _battery = Battery();

  // Static, fetched once.
  String? _platform;
  String? _appVersion;
  String? _deviceModel;
  String? _osVersion;
  bool _staticLoaded = false;

  String _currentScreen = '';
  DateTime? _lastReportAt;
  Position? _lastPosition;
  bool _started = false;

  // Throttle same-screen repeats so frequent lifecycle/nav events don't spam
  // the server. Screen changes and lifecycle resume pass force:true to skip it.
  static const _minInterval = Duration(seconds: 8);

  /// Begin reporting for the logged-in user. Safe to call again on app
  /// restore — it just refreshes the static info and sends a fresh report.
  Future<void> start(ApiClient api, {String screen = 'login'}) async {
    _api = api;
    _started = true;
    await _loadStatic();
    await report(screen: screen, force: true);
  }

  void stop() {
    _started = false;
  }

  /// Update the current-screen label. A screen change is meaningful activity,
  /// so it always triggers an immediate report.
  void setScreen(String screen) {
    final s = screen.trim();
    if (s.isEmpty || s == _currentScreen) return;
    _currentScreen = s;
    unawaited(report(force: true));
  }

  /// Tell the server the app is pausing / logging out. Best-effort.
  Future<void> reportOffline() async {
    final api = _api;
    if (api == null) return;
    try {
      await api.reportPresence(
        online: false,
        currentScreen: _currentScreen.isEmpty ? null : _currentScreen,
      );
    } catch (_) {}
  }

  Future<void> _loadStatic() async {
    if (_staticLoaded) return;
    _platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'web';
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('PresenceService: package info failed → $e');
    }
    try {
      final di = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await di.androidInfo;
        _deviceModel = '${a.manufacturer} ${a.model}'.trim();
        _osVersion = 'Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await di.iosInfo;
        _deviceModel = i.name;
        _osVersion = 'iOS ${i.systemVersion}';
      }
    } catch (e) {
      debugPrint('PresenceService: device info failed → $e');
    }
    _staticLoaded = true;
  }

  /// Send a presence report. [force] bypasses the throttle (used by screen
  /// changes and lifecycle events).
  Future<void> report({String? screen, bool force = false}) async {
    final api = _api;
    if (api == null || !_started) return;
    if (screen != null && screen.trim().isNotEmpty) {
      _currentScreen = screen.trim();
    }
    final now = DateTime.now();
    if (!force &&
        _lastReportAt != null &&
        now.difference(_lastReportAt!) < _minInterval) {
      return;
    }
    _lastReportAt = now;
    await _loadStatic();

    int? batteryPct;
    bool? charging;
    try {
      batteryPct = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      charging =
          state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {}

    final pos = await _tryLocation();

    try {
      await api.reportPresence(
        online: true,
        platform: _platform,
        appVersion: _appVersion,
        deviceModel: _deviceModel,
        osVersion: _osVersion,
        batteryPct: batteryPct,
        charging: charging,
        currentScreen: _currentScreen.isEmpty ? null : _currentScreen,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
    } catch (e) {
      debugPrint('PresenceService: report failed → $e');
    }
  }

  /// Foreground-only location. Requests WhenInUse permission once; if the user
  /// denies it we just keep reporting presence without a fix. Falls back to
  /// the last known position when a fresh fix times out.
  Future<Position?> _tryLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _lastPosition;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return _lastPosition;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      ).timeout(const Duration(seconds: 6));
      _lastPosition = pos;
      return pos;
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _lastPosition = last;
      } catch (_) {}
      return _lastPosition;
    }
  }
}

/// Navigator observer that feeds named-route pushes into the presence
/// reporter, so the dashboard shows roughly which screen each user is on.
/// Unnamed routes (most MaterialPageRoute pushes) are ignored; the bottom-nav
/// tabs report their own labels via [PresenceService.setScreen].
class PresenceNavObserver extends NavigatorObserver {
  void _report(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      PresenceService.instance.setScreen(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _report(newRoute);
  }
}
