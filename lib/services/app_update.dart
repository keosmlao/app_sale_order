import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';

/// What the server says the current Android build is.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.minBuildNumber,
    required this.downloadUrl,
    required this.notes,
    this.installedVersion = '',
  });

  final String version;
  final int buildNumber;
  final int minBuildNumber;
  final String downloadUrl;
  final String notes;
  // The build actually running on this device. Filled in by
  // mandatoryUpdate(), not by the server — shown on the update screen so
  // whoever is holding the tablet can see which version it is stuck on.
  final String installedVersion;

  static AppRelease? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final build = raw['buildNumber'];
    final min = raw['minBuildNumber'];
    if (build is! int || min is! int) return null;
    return AppRelease(
      version: (raw['version'] as String?)?.trim() ?? '',
      buildNumber: build,
      minBuildNumber: min,
      downloadUrl: (raw['downloadUrl'] as String?)?.trim() ?? '',
      notes: (raw['notes'] as String?)?.trim() ?? '',
    );
  }
}

/// Checks the running build against the one the server publishes.
///
/// Tablets on the shop floor are updated by someone walking over with the
/// download page open, so a build can sit there for months. When the server
/// raises `minBuildNumber` the app has to say so itself — nothing else will.
///
/// [required] is the answer, and the app root watches it: the moment it
/// holds a release, the update screen covers whatever is on screen. That
/// matters because a shop tablet is rarely restarted — checking once at
/// launch means a device that has been awake since Monday never hears about
/// a release published on Tuesday.
class AppUpdateService {
  AppUpdateService._();
  static final instance = AppUpdateService._();

  /// Non-null when the running build is below the server's floor.
  final ValueNotifier<AppRelease?> required = ValueNotifier<AppRelease?>(null);

  bool _inFlight = false;

  /// Ask the server what build it expects and publish the answer.
  ///
  /// Never throws, and never clears a requirement it has already found: a
  /// device that has been told it is too old stays told, even if the next
  /// check cannot reach the server. Failures are not remembered either —
  /// the earlier version latched on the first attempt, so one bad moment of
  /// wifi disabled the check for the rest of the process.
  Future<void> check(String baseUrl) async {
    if (_inFlight || required.value != null) return;
    if (baseUrl.trim().isEmpty) return;
    _inFlight = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      final res = await http
          .get(Uri.parse('$baseUrl/api/app-version'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return;
      final release = AppRelease.tryParse(jsonDecode(res.body) as Object?);
      if (release == null) return;
      debugPrint(
        '[Update] installed=$current floor=${release.minBuildNumber} '
        'published=${release.version}+${release.buildNumber}',
      );
      if (current >= release.minBuildNumber) return;
      required.value = AppRelease(
        version: release.version,
        buildNumber: release.buildNumber,
        minBuildNumber: release.minBuildNumber,
        downloadUrl: release.downloadUrl,
        notes: release.notes,
        installedVersion: '${info.version}+${info.buildNumber}',
      );
    } catch (e) {
      debugPrint('[Update] check failed: $e');
    } finally {
      _inFlight = false;
    }
  }
}

/// Full-screen, no way past it: the build cannot be trusted against this
/// server, so there is nothing useful behind the dialog to go back to.
class ForcedUpdateScreen extends StatelessWidget {
  const ForcedUpdateScreen({
    super.key,
    required this.release,
    required this.baseUrl,
  });

  final AppRelease release;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final url = release.downloadUrl.startsWith('http')
        ? release.downloadUrl
        : '$baseUrl${release.downloadUrl}';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(kSpace6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: kSpace4),
                  Text(
                    'ຕ້ອງອັບເດດແອັບກ່ອນ',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: kSpace2),
                  Text(
                    'ແອັບລຸ້ນນີ້ໃຊ້ກັບລະບົບປັດຈຸບັນບໍ່ໄດ້ແລ້ວ '
                    'ກະລຸນາຕິດຕັ້ງລຸ້ນ ${release.version} ກ່ອນຈຶ່ງໃຊ້ງານຕໍ່ໄດ້.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: kSpace3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpace4,
                      vertical: kSpace2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardElev,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'ເວີຊັນປັດຈຸບັນ: ${release.installedVersion.isEmpty ? '—' : release.installedVersion}'
                      '   •   ຕ້ອງການ: ${release.version}+${release.minBuildNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (release.notes.isNotEmpty) ...[
                    const SizedBox(height: kSpace3),
                    Text(
                      release.notes,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: kSpace5),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('ດາວໂຫຼດລຸ້ນໃໝ່'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
