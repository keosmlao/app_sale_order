import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api.dart';

// Top-level handler invoked by the OS when the app is in the
// background / terminated. Must be a top-level / static function annotated
// with @pragma so the Dart engine can find it from a fresh isolate.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in the background isolate. Plain init — no API calls
  // here, the OS already shows the notification from the `notification`
  // payload sent by lib/notify.ts.
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  String? _currentToken;

  /// Called once from main() before runApp. Sets up Firebase + the local
  /// notification plugin used to show in-app banners while the app is
  /// foregrounded. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // No google-services.json yet — keep app running. registerForUser()
      // will be a no-op until Firebase is set up.
      debugPrint('NotificationService: Firebase init failed → $e');
      return;
    }

    // Android channel matching what notify.ts targets (channelId: 'default').
    const androidChannel = AndroidNotificationChannel(
      'default',
      'ການແຈ້ງເຕືອນທົ່ວໄປ',
      description: 'ການແຈ້ງເຕືອນຈາກລະບົບ ODG Sale',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Init the local plugin so we can show notifications when the app is
    // foregrounded (FCM doesn't auto-show in that case).
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Defer message-listener wiring until after the first frame. Both calls
    // are cheap themselves, but onBackgroundMessage spawns a fresh Dart
    // isolate (visible in adb logs as FLTFireBGExecutor) which competes for
    // the main thread during launch and previously cost ~30 frames.
    _initialised = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Hand off background messages to the top-level handler.
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      // Show a local notification when a message arrives while the app is open.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    });
  }

  /// Call after login. Requests permission (iOS), grabs the FCM token, and
  /// pushes it to the server so notifications can be routed to this device.
  Future<void> registerForUser(ApiClient api) async {
    if (!_initialised) return;
    final messaging = FirebaseMessaging.instance;

    // iOS / web require explicit permission. Android grants by default.
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('NotificationService: requestPermission failed → $e');
    }

    String? token;
    try {
      token = await messaging.getToken();
    } catch (e) {
      debugPrint('NotificationService: getToken failed → $e');
      return;
    }
    if (token == null || token.isEmpty) return;
    _currentToken = token;
    await _pushToken(api, token);

    // Refresh handler — token can rotate at any time. Re-push to server.
    messaging.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      await _pushToken(api, newToken);
    });
  }

  /// Call on logout — best-effort, swallows errors so logout never blocks.
  Future<void> unregister(ApiClient api) async {
    final t = _currentToken;
    if (t == null) return;
    try {
      await api.unregisterFcmToken(token: t);
    } catch (e) {
      debugPrint('NotificationService: unregisterFcmToken failed → $e');
    }
    _currentToken = null;
  }

  Future<void> _pushToken(ApiClient api, String token) async {
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'web';
    try {
      await api.registerFcmToken(token: token, platform: platform);
    } catch (e) {
      debugPrint('NotificationService: registerFcmToken failed → $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default',
          'ການແຈ້ງເຕືອນທົ່ວໄປ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['type']?.toString(),
    );
  }
}
