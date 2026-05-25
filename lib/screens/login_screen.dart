import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_scope.dart';
import '../app_theme.dart';
import '../config.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _codeCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.of(context).auth.login(_codeCtl.text.trim(), _pwdCtl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openApiUrlSettings() async {
    final scope = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApiUrlSheet(api: scope.api, config: scope.config),
    );
    if (mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Settings gear lives in the app bar so we don't overlap content with
      // an absolutely-positioned button.
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'ກຳນົດ URL API',
            onPressed: _openApiUrlSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeInSlide(
                duration: const Duration(milliseconds: 700),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand — small monogram + name. The wordmark stays modest
                      // so the form is the visual anchor on the screen.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(kRadiusMd),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'O',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Two-line headline. The big line is the call to action,
                      // the small line tells the user what to type in.
                      Text(
                        'ເຂົ້າສູ່ລະບົບ',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ໃຊ້ລະຫັດພະນັກງານ ແລະ ລະຫັດຜ່ານເພື່ອເລີ່ມໃຊ້ງານ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 28),

                      // Employee code.
                      TextField(
                        controller: _codeCtl,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'ລະຫັດພະນັກງານ',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Password — with show/hide toggle.
                      TextField(
                        controller: _pwdCtl,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => _loading ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'ລະຫັດຜ່ານ',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'ສະແດງລະຫັດ' : 'ເຊື່ອງລະຫັດ',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),

                      // Error banner — soft red tint, no border. Only renders when
                      // there's actually something to say.
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(kRadiusMd),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submit. Theme-styled FilledButton, full width, 46px tall.
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('ເຂົ້າສູ່ລະບົບ'),
                      ),

                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'ODG · ລະບົບຂາຍ ສຳລັບພະນັກງານ',
                          style: TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── API URL settings bottom sheet ────────────────────────────────────────
// Lets the user point the app at a different server (dev / prod / branch).
// Inherits the new theme so it reads as just another sheet — no gold accents.

class _ApiUrlSheet extends StatefulWidget {
  const _ApiUrlSheet({required this.api, required this.config});

  final dynamic api; // ApiClient
  final ConfigService config;

  @override
  State<_ApiUrlSheet> createState() => _ApiUrlSheetState();
}

class _ApiUrlSheetState extends State<_ApiUrlSheet> {
  late final TextEditingController _ctl;
  bool _testing = false;
  bool _saving = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.api.baseUrl as String);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = _ctl.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResult = 'ກະລຸນາປ້ອນ URL';
        _testOk = false;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      // Any HTTP response (even 401/404) means the host is reachable.
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testResult = 'ເຊື່ອມຕໍ່ສຳເລັດ (HTTP ${res.statusCode})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testResult = 'ເຊື່ອມຕໍ່ບໍ່ໄດ້: $e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final url = _ctl.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.config.saveApiBaseUrl(url);
      widget.api.baseUrl = url;
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetToDefault() {
    setState(() {
      _ctl.text = AppConfig.defaultApiBaseUrl;
      _testResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // (Theme provides the drag handle at the top automatically.)
          Text(
            'ກຳນົດ URL API',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'ບັນທຶກໄວ້ໃນເຄື່ອງ; ໃຊ້ສະເພາະເຄື່ອງນີ້.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctl,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'http://10.0.40.11:3000',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(
                'ໃຊ້ຄ່າເລີ່ມຕົ້ນ (${AppConfig.defaultApiBaseUrl})',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: (_testOk ? AppColors.success : AppColors.danger)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    _testOk ? Icons.check_circle_outline : Icons.error_outline,
                    color: _testOk ? AppColors.success : AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testOk ? AppColors.success : AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check, size: 18),
                  label: Text(_testing ? 'ກຳລັງທົດສອບ…' : 'ທົດສອບ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_saving ? 'ກຳລັງບັນທຶກ…' : 'ບັນທຶກ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}