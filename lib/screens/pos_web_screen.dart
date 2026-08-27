import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../app_scope.dart';
import '../app_theme.dart';

/// The counter tablet's sales screen: the web POS itself, at /orders/new.
///
/// It was a native rebuild of that page, and keeping the two the same by
/// hand did not work — every fix closed one gap and left another, because
/// the web POS keeps moving and nothing forces the app to follow. Loading
/// the page means it cannot drift: one screen, one promotion engine (see
/// /api/promotions/price), one set of rules about what the storefront may
/// sell.
///
/// The app still owns everything around it — the rail, stock, promotions,
/// forced updates, the scanner, presence reporting.
class PosWebScreen extends StatefulWidget {
  const PosWebScreen({super.key, this.path = '/orders/new?embed=1'});

  final String path;

  @override
  State<PosWebScreen> createState() => _PosWebScreenState();
}

class _PosWebScreenState extends State<PosWebScreen>
    with AutomaticKeepAliveClientMixin {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  // The tab lives in an IndexedStack; without this the page would reload
  // from scratch every time the cashier looked at stock and came back,
  // losing a half-built cart.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _boot();
    });
  }

  Future<void> _boot() async {
    final scope = AppScope.of(context);
    final baseUrl = scope.api.baseUrl;
    final token = scope.api.token;

    if (token == null || token.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'ຍັງບໍ່ໄດ້ເຂົ້າສູ່ລະບົບ — ກະລຸນາອອກແລ້ວເຂົ້າໃໝ່';
      });
      return;
    }

    // The Bearer token the app holds IS a session token — /api/auth/login
    // mints one and getEmployeeFromRequest() accepts it from either the
    // Authorization header or the odg_session cookie. Planting it as the
    // cookie signs the page in as the same employee, so nobody logs in
    // twice.
    final host = Uri.parse(baseUrl).host;
    await WebViewCookieManager().setCookie(
      WebViewCookie(name: 'odg_session', value: token, domain: host, path: '/'),
    );

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            // Sub-resource failures (an image, a font) are not the page
            // failing — only report when the document itself did not load.
            if (!e.isForMainFrame!) return;
            if (mounted) {
              setState(() {
                _loading = false;
                _error = 'ໂຫຼດໜ້າຂາຍບໍ່ໄດ້ — ກວດອິນເຕີເນັດ ແລ້ວລອງໃໝ່';
              });
            }
          },
        ),
      );

    // Let the page use the tablet camera for barcode scanning without a
    // second prompt: Android has already granted it to the app.
    if (Platform.isAndroid) {
      final android = controller.platform as AndroidWebViewController;
      await android.setOnPlatformPermissionRequest(
        (request) => request.grant(),
      );
    }

    await controller.loadRequest(Uri.parse('$baseUrl${widget.path}'));
    if (!mounted) return;
    setState(() => _controller = controller);
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
      _controller = null;
    });
    await _boot();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(kSpace6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 44,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: kSpace3),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: kSpace4),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('ລອງໃໝ່'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    return Scaffold(
      backgroundColor: AppColors.bg,
      // The page sizes itself to the viewport it is given, and the home
      // shell deliberately does not pad the bottom — native screens handle
      // their own insets. A web page cannot, so without this the pay
      // button at the foot of the sale rail sits behind Android's
      // navigation bar.
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            if (controller != null) WebViewWidget(controller: controller),
            if (_loading)
              const Positioned.fill(
                child: BrandedSpinner(label: 'ກຳລັງເປີດໜ້າຂາຍ…'),
              ),
          ],
        ),
      ),
    );
  }
}
