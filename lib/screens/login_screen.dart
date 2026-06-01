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
  final _codeFocus = FocusNode();
  final _pwdFocus = FocusNode();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _codeCtl.dispose();
    _pwdCtl.dispose();
    _codeFocus.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_codeCtl.text.trim().isEmpty || _pwdCtl.text.isEmpty) {
      setState(() => _error = 'ກະລຸນາປ້ອນລະຫັດພະນັກງານ ແລະ ລະຫັດຜ່ານ');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.of(context).auth.login(_codeCtl.text.trim(), _pwdCtl.text);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Strip "Exception:" prefixes and surface the meaningful tail.
  String _humanError(String raw) {
    final cleaned = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (cleaned.isEmpty) return 'ເຂົ້າສູ່ລະບົບບໍ່ສຳເລັດ';
    return cleaned;
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
    final isDark = ThemeService.isDark;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideView = constraints.maxWidth >= kWideBreakpoint;
          final maxFormWidth = isWideView ? 440.0 : 520.0;
          final isShortView = constraints.maxHeight < 760;
          final horizontalPadding = isWideView ? kSpace10 : kSpace4;
          final verticalPadding = isShortView ? kSpace2 : kSpace4;
          final sectionGap = isShortView ? kSpace3 : kSpace5;

          return SingleChildScrollView(
            child: SizedBox(
              height: constraints.maxHeight,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    verticalPadding,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWideView ? 980 : maxFormWidth,
                      ),
                      child: SizedBox.expand(
                        child: isWideView
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(
                                    child: _LoginDashboardPanel(fill: true),
                                  ),
                                  const SizedBox(width: kSpace10),
                                  SizedBox(
                                    width: maxFormWidth,
                                    child: _LoginFormPanel(
                                      isDark: isDark,
                                      codeCtl: _codeCtl,
                                      pwdCtl: _pwdCtl,
                                      codeFocus: _codeFocus,
                                      pwdFocus: _pwdFocus,
                                      obscure: _obscure,
                                      loading: _loading,
                                      error: _error,
                                      onToggleObscure: () =>
                                          setState(() => _obscure = !_obscure),
                                      onSubmit: _submit,
                                      onOpenSettings: _openApiUrlSettings,
                                      onToggleTheme: () {
                                        setState(ThemeService.toggleTheme);
                                      },
                                      fill: true,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _LoginTopBar(
                                    onToggleTheme: () {
                                      setState(ThemeService.toggleTheme);
                                    },
                                    onOpenSettings: _openApiUrlSettings,
                                  ),
                                  SizedBox(height: sectionGap),
                                  const Expanded(
                                    child: _LoginDashboardPanel(
                                      compact: true,
                                      fill: true,
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  _LoginFormPanel(
                                    isDark: isDark,
                                    codeCtl: _codeCtl,
                                    pwdCtl: _pwdCtl,
                                    codeFocus: _codeFocus,
                                    pwdFocus: _pwdFocus,
                                    obscure: _obscure,
                                    loading: _loading,
                                    error: _error,
                                    onToggleObscure: () =>
                                        setState(() => _obscure = !_obscure),
                                    onSubmit: _submit,
                                    onOpenSettings: _openApiUrlSettings,
                                    onToggleTheme: () {
                                      setState(ThemeService.toggleTheme);
                                    },
                                    showActions: false,
                                    compact: true,
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
        },
      ),
    );
  }
}

class _LoginTopBar extends StatelessWidget {
  const _LoginTopBar({
    required this.onToggleTheme,
    required this.onOpenSettings,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconActionButton(
          tooltip: 'ປ່ຽນໂໝດແສງ',
          icon: ThemeService.isDark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          onPressed: onToggleTheme,
        ),
        const SizedBox(width: kSpace2),
        _IconActionButton(
          tooltip: 'ກຳນົດ URL API',
          icon: Icons.tune_rounded,
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}

class _LoginDashboardPanel extends StatelessWidget {
  const _LoginDashboardPanel({this.compact = false, this.fill = false});

  final bool compact;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return FadeInSlide(
      duration: kMotionSlow,
      child: Container(
        padding: EdgeInsets.all(compact ? kSpace4 : kSpace6),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(kRadiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              children: [
                BrandMark(size: compact ? 58 : 76),
                const SizedBox(width: kSpace4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ODG Sale',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: compact ? 23 : 30,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Dashboard Login',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? kSpace4 : kSpace6),
            Text(
              'ພາບລວມວຽກຂາຍກ່ອນເຂົ້າລະບົບ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: compact ? 18 : 24,
                fontWeight: FontWeight.w800,
                height: 1.28,
              ),
            ),
            SizedBox(height: compact ? kSpace3 : kSpace4),
            Container(
              padding: const EdgeInsets.all(kSpace3),
              decoration: BoxDecoration(
                color: AppColors.cardElev.withValues(
                  alpha: ThemeService.isDark ? 0.5 : 0.85,
                ),
                borderRadius: BorderRadius.circular(kRadiusLg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(
                      'ລະບົບພ້ອມໃຊ້ງານ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.wifi_tethering_rounded,
                    color: AppColors.success,
                    size: 18,
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? kSpace3 : kSpace6),
            _DashboardMetricGrid(compact: compact),
            if (fill) const Spacer(),
            if (!compact) const _DashboardWorkflow(),
          ],
        ),
      ),
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.isDark,
    required this.codeCtl,
    required this.pwdCtl,
    required this.codeFocus,
    required this.pwdFocus,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onOpenSettings,
    required this.onToggleTheme,
    this.showActions = true,
    this.compact = false,
    this.fill = false,
  });

  final bool isDark;
  final TextEditingController codeCtl;
  final TextEditingController pwdCtl;
  final FocusNode codeFocus;
  final FocusNode pwdFocus;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleTheme;
  final bool showActions;
  final bool compact;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return FadeInSlide(
      delay: const Duration(milliseconds: 120),
      child: Container(
        padding: EdgeInsets.all(compact ? kSpace4 : kSpace5),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(kRadiusXl),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ເຂົ້າສູ່ລະບົບ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: compact ? 21 : 24,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ໃຊ້ລະຫັດພະນັກງານຂອງທ່ານ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showActions)
                  _LoginTopBar(
                    onToggleTheme: onToggleTheme,
                    onOpenSettings: onOpenSettings,
                  ),
              ],
            ),
            SizedBox(height: compact ? kSpace4 : kSpace6),
            _LoginTextField(
              label: 'ລະຫັດພະນັກງານ',
              hint: 'ຕົວຢ່າງ: 1001',
              icon: Icons.badge_outlined,
              controller: codeCtl,
              focusNode: codeFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => pwdFocus.requestFocus(),
              compact: compact,
            ),
            SizedBox(height: compact ? kSpace3 : kSpace4),
            _LoginTextField(
              label: 'ລະຫັດຜ່ານ',
              hint: 'ປ້ອນລະຫັດຜ່ານ',
              icon: Icons.lock_outline_rounded,
              controller: pwdCtl,
              focusNode: pwdFocus,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!loading) onSubmit();
              },
              suffixIcon: IconButton(
                tooltip: obscure ? 'ສະແດງລະຫັດ' : 'ເຊື່ອງລະຫັດ',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
              compact: compact,
            ),
            if (error != null) ...[
              SizedBox(height: compact ? kSpace3 : kSpace4),
              InlineBanner(kind: BannerKind.error, message: error!),
            ],
            SizedBox(height: compact ? kSpace4 : kSpace6),
            _LoginSubmitButton(
              loading: loading,
              onPressed: loading ? null : onSubmit,
              compact: compact,
            ),
            if (fill) const Spacer(),
            SizedBox(height: compact ? kSpace3 : kSpace5),
            const _LoginFooter(),
          ],
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.focusNode,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.compact = false,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(icon: icon, text: label),
        const SizedBox(height: kSpace2),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          textInputAction: textInputAction,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: onSubmitted,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.cardElev.withValues(
              alpha: ThemeService.isDark ? 0.42 : 0.75,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.6,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: kSpace4,
              vertical: compact ? 12 : 15,
            ),
            isDense: compact,
          ),
        ),
      ],
    );
  }
}

class _LoginSubmitButton extends StatelessWidget {
  const _LoginSubmitButton({
    required this.loading,
    required this.onPressed,
    this.compact = false,
  });

  final bool loading;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.login_rounded, size: 20),
        label: Text(
          loading ? 'ກຳລັງເຂົ້າລະບົບ...' : 'ເຂົ້າສູ່ລະບົບ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.cardElev,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricGrid extends StatelessWidget {
  const _DashboardMetricGrid({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _DashboardMetricTile(
        icon: Icons.receipt_long_rounded,
        label: 'Orders',
        value: 'ອໍເດີ',
        color: AppColors.primary,
        compact: compact,
      ),
      _DashboardMetricTile(
        icon: Icons.inventory_2_rounded,
        label: 'Stock',
        value: 'ສະຕັອກ',
        color: AppColors.accent,
        compact: compact,
      ),
      _DashboardMetricTile(
        icon: Icons.verified_rounded,
        label: 'Approval',
        value: 'ອະນຸມັດ',
        color: AppColors.warning,
        compact: compact,
      ),
    ];

    if (compact) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: kSpace2),
          ],
        ],
      );
    }

    return Wrap(spacing: kSpace3, runSpacing: kSpace3, children: [...tiles]);
  }
}

class _DashboardMetricTile extends StatelessWidget {
  const _DashboardMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : 138,
      padding: EdgeInsets.all(compact ? kSpace2 : kSpace3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ThemeService.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 17 : 20, color: color),
          SizedBox(height: compact ? kSpace2 : kSpace3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: compact ? 13 : 16,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (!compact) const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardWorkflow extends StatelessWidget {
  const _DashboardWorkflow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kSpace6),
        Text(
          'Workflow',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: kSpace3),
        Row(
          children: [
            _WorkflowStep(
              icon: Icons.add_shopping_cart_rounded,
              text: 'ສ້າງອໍເດີ',
              color: AppColors.primary,
            ),
            const _WorkflowLine(),
            _WorkflowStep(
              icon: Icons.warehouse_rounded,
              text: 'ກວດສະຕັອກ',
              color: AppColors.accent,
            ),
            const _WorkflowLine(),
            _WorkflowStep(
              icon: Icons.check_circle_rounded,
              text: 'ອະນຸມັດ',
              color: AppColors.success,
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: kSpace2),
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowLine extends StatelessWidget {
  const _WorkflowLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'ODG · v1.0',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── API URL settings bottom sheet ────────────────────────────────────────

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
      padding: EdgeInsets.fromLTRB(
        kSpace5,
        kSpace2,
        kSpace5,
        kSpace5 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBubble(
                icon: Icons.link_rounded,
                color: AppColors.info,
                size: BubbleSize.md,
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ກຳນົດ URL API',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ບັນທຶກໄວ້ໃນເຄື່ອງ — ໃຊ້ສະເພາະອຸປະກອນນີ້',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace5),
          TextField(
            controller: _ctl,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'http://10.0.40.11:3000',
              prefixIcon: Icon(Icons.public_rounded),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
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
            const SizedBox(height: kSpace3),
            InlineBanner(
              kind: _testOk ? BannerKind.success : BannerKind.error,
              message: _testResult!,
            ),
          ],
          const SizedBox(height: kSpace5),
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
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(_testing ? 'ກຳລັງທົດສອບ…' : 'ທົດສອບ'),
                ),
              ),
              const SizedBox(width: kSpace3),
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
                      : const Icon(Icons.check_rounded, size: 18),
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
