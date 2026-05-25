import 'package:flutter/widgets.dart';
import 'config.dart';
import 'services/api.dart';
import 'services/auth.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.auth,
    required this.config,
    required super.child,
  });

  final ApiClient api;
  final AuthService auth;
  final ConfigService config;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      auth != oldWidget.auth ||
      config != oldWidget.config;
}
