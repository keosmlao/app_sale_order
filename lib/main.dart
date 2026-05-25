import 'package:flutter/material.dart';
import 'app_scope.dart';
import 'app_theme.dart';
import 'config.dart';
import 'services/api.dart';
import 'services/auth.dart';
import 'services/notifications.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _OdgSaleAppState extends State<OdgSaleApp> {
  late final ApiClient _api;
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: widget.baseUrl);
    _auth = AuthService(_api);
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
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: currentMode == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return GlassBackground(
                child: MediaQuery(
                  data: media.copyWith(textScaler: TextScaler.linear(0.94)),
                  child: child ?? const SizedBox.shrink(),
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
  Future<bool>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).auth.tryRestore();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
