import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_theme.dart';

class AppConfig {
  // Compile-time fallback. Overridden at runtime by [ConfigService] when the
  // user picks a URL in settings.
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  // Kept for back-compat. Anywhere reading this still gets the compile-time
  // value; runtime code should use ApiClient.baseUrl instead.
  static const String apiBaseUrl = defaultApiBaseUrl;
}

/// Persists the API base URL and Theme Mode chosen by the user.
class ConfigService {
  static const _key = 'api_base_url';
  static const _themeKey = 'theme_mode';
  final _storage = const FlutterSecureStorage();

  Future<String> loadApiBaseUrl() async {
    final saved = await _storage.read(key: _key);
    final value = saved?.trim();
    if (value == null || value.isEmpty) return AppConfig.defaultApiBaseUrl;
    return _normalize(value);
  }

  Future<void> saveApiBaseUrl(String url) async {
    final normalized = _normalize(url);
    await _storage.write(key: _key, value: normalized);
  }

  Future<AppThemeMode> loadThemeMode() async {
    final saved = await _storage.read(key: _themeKey);
    if (saved == 'dark') return AppThemeMode.dark;
    return AppThemeMode.light;
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    await _storage.write(
      key: _themeKey,
      value: mode == AppThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _themeKey);
  }

  // Strip trailing slashes so callers can concat paths safely.
  String _normalize(String url) {
    var v = url.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }
}
