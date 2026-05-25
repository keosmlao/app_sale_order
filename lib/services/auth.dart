import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import 'api.dart';
import 'notifications.dart';

class AuthService {
  AuthService(this.api);

  final ApiClient api;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'odg_token';

  Employee? employee;

  Future<String?> loadToken() async {
    final token = await _storage.read(key: _tokenKey);
    api.token = token;
    return token;
  }

  Future<void> login(String code, String password) async {
    final result = await api.login(code, password);
    api.token = result.token;
    employee = result.employee;
    await _storage.write(key: _tokenKey, value: result.token);
    // Push FCM token now that we have an auth bearer + know the user.
    // Fire-and-forget so a slow token grab doesn't block the login screen.
    NotificationService.instance.registerForUser(api);
  }

  Future<bool> tryRestore() async {
    final token = await loadToken();
    if (token == null) return false;
    try {
      employee = await api.me();
      // Same as login — refresh device registration on app restart so a
      // rotated FCM token gets re-pushed.
      NotificationService.instance.registerForUser(api);
      return true;
    } on ApiException catch (e) {
      // statusCode 0 = network never reached the server. Keep the token so
      // the user is auto-restored as soon as connectivity returns; clearing
      // it would force a re-login while offline (which would also fail).
      if (e.statusCode == 0) return false;
      // Real auth rejection (401/403/410/etc.) — token is no good, wipe.
      await logout();
      return false;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    // Detach this device from the user *before* clearing the auth token —
    // the DELETE endpoint needs the bearer to authenticate. Best-effort.
    await NotificationService.instance.unregister(api);
    api.token = null;
    employee = null;
    await _storage.delete(key: _tokenKey);
  }
}
