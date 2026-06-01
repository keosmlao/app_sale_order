import 'package:flutter/material.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ອອກຈາກລະບົບ'),
        content: const Text('ຕ້ອງການອອກຈາກລະບົບແທ້ບໍ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ຍົກເລີກ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('ອອກຈາກລະບົບ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    await AppScope.of(context).auth.logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final emp = AppScope.of(context).auth.employee;
    final displayName = emp?.displayName ?? '—';
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();
    final positionLabel = emp == null ? null : roleLabelLao(emp.appRole);
    final isManager = emp?.appRole == AppRole.manager;

    return ColoredBox(
      color: AppColors.bg,
      child: TabletConstrain(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 110),
          children: [
            FadeInSlide(
              child: _ProfileHero(
                displayName: displayName,
                nickname: emp?.nickname,
                initial: initial,
                positionLabel: positionLabel,
                employeeCode: emp?.employeeCode,
                isManager: isManager,
              ),
            ),

            const SizedBox(height: kSpace3),
            FadeInSlide(
              delay: const Duration(milliseconds: 120),
              child: _Section(
                title: 'ຂໍ້ມູນພະນັກງານ',
                icon: Icons.person_rounded,
                accent: AppColors.info,
                child: _kvList([
                  _Kv('ລະຫັດ', emp?.employeeCode),
                  _Kv('ຊື່ ພາສາລາວ', emp?.fullnameLo),
                  _Kv('ຊື່ ພາສາອັງກິດ', emp?.fullnameEn),
                  _Kv('ຕຳແໜ່ງ', positionLabel),
                ]),
              ),
            ),

            const SizedBox(height: kSpace3),
            FadeInSlide(
              delay: const Duration(milliseconds: 200),
              child: _Section(
                title: 'ການຕັ້ງຄ່າ',
                icon: Icons.tune_rounded,
                accent: AppColors.accent,
                child: ValueListenableBuilder<AppThemeMode>(
                  valueListenable: ThemeService.themeModeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == AppThemeMode.dark;
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ໂໝດໜ້າຈໍ',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDark
                                    ? 'ກາງຄືນ — Dark Mode'
                                    : 'ກາງເວັນ — Light Mode',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ThemeSwitch(
                          isDark: isDark,
                          onChanged: (val) async {
                            final newMode = val
                                ? AppThemeMode.dark
                                : AppThemeMode.light;
                            ThemeService.setThemeMode(newMode);
                            await AppScope.of(
                              context,
                            ).config.saveThemeMode(newMode);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: kSpace3),
            FadeInSlide(
              delay: const Duration(milliseconds: 280),
              child: SurfaceCard(
                onTap: () => _logout(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace3 + 2,
                ),
                child: Row(
                  children: [
                    IconBubble(
                      icon: Icons.logout_rounded,
                      color: AppColors.danger,
                      size: BubbleSize.md,
                    ),
                    const SizedBox(width: kSpace3),
                    Expanded(
                      child: Text(
                        'ອອກຈາກລະບົບ',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.danger.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvList(List<_Kv> rows) {
    return Column(
      children: List.generate(rows.length, (i) {
        final r = rows[i];
        final isLast = i == rows.length - 1;
        return Container(
          padding: const EdgeInsets.fromLTRB(0, kSpace3, 0, kSpace3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isLast ? Colors.transparent : AppColors.divider,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  r.key,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  (r.value == null || r.value!.trim().isEmpty) ? '—' : r.value!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.initial,
    required this.isManager,
    this.nickname,
    this.positionLabel,
    this.employeeCode,
  });

  final String displayName;
  final String initial;
  final bool isManager;
  final String? nickname;
  final String? positionLabel;
  final String? employeeCode;

  @override
  Widget build(BuildContext context) {
    final cleanNickname = nickname?.trim();

    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(
              alpha: ThemeService.isDark ? 0.18 : 0.22,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(kRadiusLg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    if (cleanNickname != null &&
                        cleanNickname.isNotEmpty &&
                        cleanNickname != '0') ...[
                      const SizedBox(height: 4),
                      Text(
                        cleanNickname,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: kSpace2),
                    Text(
                      isManager ? 'Manager workspace' : 'Sales workspace',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace4),
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: [
              if (positionLabel != null)
                _HeroChip(
                  icon: isManager
                      ? Icons.admin_panel_settings_rounded
                      : Icons.badge_rounded,
                  label: positionLabel!,
                ),
              if (employeeCode != null)
                _HeroChip(
                  icon: Icons.qr_code_rounded,
                  label: employeeCode!,
                  monospace: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    this.monospace = false,
  });
  final IconData icon;
  final String label;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace3,
        vertical: kSpace2 - 1,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: monospace ? 0.6 : 0,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        kSpace4,
        kSpace3,
        kSpace4,
        kSpace3 + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: icon, color: accent, size: BubbleSize.sm),
              const SizedBox(width: kSpace2),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
          child,
        ],
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!isDark),
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.warning.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.30)
                : AppColors.warning.withValues(alpha: 0.30),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary : AppColors.warning,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _Kv {
  const _Kv(this.key, this.value);
  final String key;
  final String? value;
}
