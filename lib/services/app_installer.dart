import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thrown when the update cannot be downloaded or installed. [message] is
/// already in Lao and safe to show on the update screen as-is.
class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// In-app updater for the sales APK.
///
/// Ported from app_tms (lib/src/services/app_updater.dart) so the two
/// company apps update the same way. Neither is on Play — a release is
/// copied to the company server — and dropping someone into a browser
/// download they then have to find in Files is where the update stops
/// happening. The APK is streamed here with a progress bar and handed
/// straight to the system installer.
abstract final class AppInstaller {
  static const String apkMimeType = 'application/vnd.android.package-archive';

  /// Only Android can install an APK; anything else falls back to opening
  /// the link in a browser.
  static bool get canInstallInApp => Platform.isAndroid;

  /// Resolve the published download URL. A relative value ("/downloads/
  /// odg-sale.apk", which is what /api/app-version returns) is resolved
  /// against the server the app is talking to.
  static Uri? resolveUrl(String url, {required String baseUrl}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final target = Uri.tryParse(trimmed);
    if (target == null) return null;
    if (target.hasScheme) return target;
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || !base.hasScheme) return null;
    return base.resolveUri(target);
  }

  /// Stream the APK to the app's cache directory.
  ///
  /// [onProgress] receives 0..1, or -1 while the size is unknown (no
  /// Content-Length) so the UI can show an indeterminate bar rather than
  /// one frozen at zero.
  static Future<File> download(
    Uri url, {
    void Function(double progress, int received, int total)? onProgress,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .send(http.Request('GET', url))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw AppUpdateException(
          'ໂຫຼດໄຟລ໌ອັບເດດບໍ່ໄດ້ (${response.statusCode}) — ກະລຸນາແຈ້ງ IT',
        );
      }
      final total = response.contentLength ?? 0;

      // Cache dir: cleared by the OS under storage pressure and covered by
      // the installer's FileProvider, so no storage permission is needed.
      final dir = await getTemporaryDirectory();
      final name =
          url.pathSegments.isNotEmpty && url.pathSegments.last.isNotEmpty
          ? url.pathSegments.last
          : 'odg-sale-update.apk';
      final target = File(
        '${dir.path}/${name.endsWith('.apk') ? name : '$name.apk'}',
      );
      // Download to a temp name and rename on completion, so an interrupted
      // download can never be handed to the installer as if it were whole.
      final part = File('${target.path}.part');
      if (await part.exists()) await part.delete();
      if (await target.exists()) await target.delete();

      final sink = part.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total > 0 ? received / total : -1, received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (total > 0 && received < total) {
        await part.delete();
        throw const AppUpdateException(
          'ໄຟລ໌ອັບເດດໂຫຼດບໍ່ຄົບ — ກວດອິນເຕີເນັດ ແລ້ວລອງໃໝ່',
        );
      }
      await part.rename(target.path);
      return target;
    } on AppUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AppUpdateException(
        'ໂຫຼດອັບເດດຊ້າເກີນໄປ — ກວດອິນເຕີເນັດ ແລ້ວລອງໃໝ່',
      );
    } on SocketException {
      throw const AppUpdateException(
        'ຕິດຕໍ່ server ບໍ່ໄດ້ — ກວດອິນເຕີເນັດ ແລ້ວລອງໃໝ່',
      );
    } on http.ClientException {
      throw const AppUpdateException(
        'ຕິດຕໍ່ server ບໍ່ໄດ້ — ກວດອິນເຕີເນັດ ແລ້ວລອງໃໝ່',
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Hand the downloaded APK to the system installer.
  ///
  /// Android 8+ requires the user to allow this app to install apps. Asking
  /// up front means one clear prompt instead of an intent that is refused
  /// with nothing on screen to explain it.
  static Future<void> install(File apk) async {
    if (!await apk.exists()) {
      throw const AppUpdateException('ບໍ່ພົບໄຟລ໌ອັບເດດ — ກະລຸນາໂຫຼດໃໝ່');
    }
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      throw const AppUpdateException(
        'ຕ້ອງອະນຸຍາດ "ຕິດຕັ້ງແອັບຈາກແຫຼ່ງນີ້" ໃນການຕັ້ງຄ່າກ່ອນ ຈຶ່ງຈະອັບເດດໄດ້',
      );
    }
    final result = await OpenFilex.open(apk.path, type: apkMimeType);
    if (result.type != ResultType.done) {
      throw AppUpdateException('ເປີດຕົວຕິດຕັ້ງບໍ່ໄດ້ — ${result.message}');
    }
  }
}
