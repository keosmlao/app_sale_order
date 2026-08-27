import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_scope.dart';
import 'app_theme.dart';
import 'config.dart';
import 'services/api.dart';
import 'services/auth.dart';
import 'services/app_update.dart';
import 'services/notifications.dart';
import 'services/presence.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A counter tablet is landscape. Turned upright it is 800px wide, which
  // is under the 1180px the POS splits at, so the page dropped to the
  // narrow one-step-at-a-time layout meant for a phone — catalogue gone,
  // wizard back. Nobody sells from a till held upright, so it is pinned.
  //
  // Phones are left alone: shortestSide is the standard tablet test, and
  // a phone in landscape is not what this is for.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSide =
      (view.physicalSize.shortestSide / view.devicePixelRatio);
  if (shortestSide >= 600) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Run startup awaits in parallel — config (secure storage read), theme, and
  // notifications (Firebase init + local-notif plugin) don't depend on each
  // other.
  final config = ConfigService();
  final configFuture = config.loadApiBaseUrl();
  final themeFuture = config.loadThemeMode();
  final notifFuture = NotificationService.instance.initialize();
  final baseUrl = await configFuture;
  final themeMode = await themeFuture;
  await notifFuture;

  // Set the initial theme mode in the theme service
  ThemeService.setThemeMode(themeMode);

  runApp(OdgSaleApp(baseUrl: baseUrl, config: config));
}

class OdgSaleApp extends StatefulWidget {
  const OdgSaleApp({super.key, required this.baseUrl, required this.config});

  final String baseUrl;
  final ConfigService config;

  @override
  State<OdgSaleApp> createState() => _OdgSaleAppState();
}

class _OdgSaleAppState extends State<OdgSaleApp> with WidgetsBindingObserver {
  late final ApiClient _api;
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: widget.baseUrl);
    _auth = AuthService(_api);
    // App lifecycle drives presence: a resume is "activity" (report online);
    // pause/detach reports offline so the monitor reflects backgrounding.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PresenceService.instance.report(force: true);
      // A shop tablet is put down, not shut down. Resume is the moment it
      // is most likely to have missed a release, and the safest one to
      // interrupt: nobody is mid-keystroke.
      unawaited(AppUpdateService.instance.check(_api.baseUrl));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      PresenceService.instance.reportOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: _api,
      auth: _auth,
      config: widget.config,
      child: ValueListenableBuilder<AppThemeMode>(
        valueListenable: ThemeService.themeModeNotifier,
        builder: (context, currentMode, _) {
          return MaterialApp(
            title: 'ODG Sale',
            debugShowCheckedModeBanner: false,
            // Shared key so push notifications can navigate without a
            // BuildContext (tap a "new order" alert → open that order).
            navigatorKey: NotificationService.navigatorKey,
            navigatorObservers: [PresenceNavObserver()],
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: currentMode == AppThemeMode.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return AmbientGradientBackground(
                child: MediaQuery(
                  data: media.copyWith(textScaler: TextScaler.linear(0.94)),
                  // The update gate sits above every route rather than
                  // inside the boot screen. A build below the server's
                  // floor cannot be trusted against it, so it goes no
                  // further — signed in or not, and whatever screen it
                  // happened to be on when the answer arrived.
                  child: ValueListenableBuilder<AppRelease?>(
                    valueListenable: AppUpdateService.instance.required,
                    builder: (context, release, inner) {
                      if (release != null) {
                        return ForcedUpdateScreen(
                          release: release,
                          baseUrl: _api.baseUrl,
                        );
                      }
                      return inner ?? const SizedBox.shrink();
                    },
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
            home: const _Bootstrap(),
          );
        },
      ),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Future<_Boot>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _boot();
  }

  // Restore the session and ask the server what build it expects, in
  // parallel — neither waits on the other, and the update check never
  // fails the boot.
  Future<_Boot> _boot() async {
    final scope = AppScope.of(context);
    // Kicked off, not awaited: the update gate above the navigator shows
    // the screen when the answer lands, so restoring the session does not
    // wait on a network call that may time out.
    unawaited(AppUpdateService.instance.check(scope.api.baseUrl));
    return _Boot(signedIn: await scope.auth.tryRestore());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Boot>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final boot = snap.data;
        return boot?.signedIn == true
            ? const HomeScreen()
            : const LoginScreen();
      },
    );
  }
}

class _Boot {
  const _Boot({required this.signedIn});
  final bool signedIn;
}
