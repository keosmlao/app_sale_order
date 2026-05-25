import 'package:flutter/material.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import 'login_screen.dart';
import 'manager_screens.dart';

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

    return TabletConstrain(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          // — Hero: avatar + name + code chip ------------------------------
          _GlassCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.goldBright, AppColors.gold],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                if (emp?.nickname != null &&
                    emp!.nickname!.trim().isNotEmpty &&
                    emp.nickname != '0') ...[
                  const SizedBox(height: 2),
                  Text(
                    '"${emp.nickname}"',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (emp?.employeeCode != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      emp!.employeeCode!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),
          _sectionLabel('ຂໍ້ມູນພະນັກງານ', icon: Icons.badge_outlined),
          const SizedBox(height: 10),
          _Card(
            child: _kvList([
              _Kv('ລະຫັດ', emp?.employeeCode),
              _Kv('ຊື່ ພາສາລາວ', emp?.fullnameLo),
              _Kv('ຊື່ ພາສາອັງກິດ', emp?.fullnameEn),
              _Kv('ຕຳແໜ່ງ', positionLabel),
            ]),
          ),

          // Manager Hub entry — only shown to managers. Opens a grid of
          // team analytics, promotion + loyalty management, stock refill
          // approvals, and the member / employee directory.
          if (emp?.appRole == AppRole.manager) ...[
            const SizedBox(height: 22),
            _sectionLabel('ສຳລັບຜູ້ຈັດການ',
                icon: Icons.admin_panel_settings_outlined),
            const SizedBox(height: 10),
            _Card(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManagerHubScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(kRadiusMd),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(kRadiusSm),
                        ),
                        child: Icon(
                          Icons.dashboard_customize_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ເປີດ Manager Hub',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ບົດລາຍງານທີມ, promotion, loyalty, stock refill',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),
          _sectionLabel('ການຕັ້ງຄ່າລະບົບ', icon: Icons.settings_outlined),
          const SizedBox(height: 10),
          _Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ໂໝດໜ້າຈໍ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ThemeService.isDark ? 'ໂໝດກາງຄືນ (Dark Mode)' : 'ໂໝດກາງເວັນ (Light Mode)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<AppThemeMode>(
                    valueListenable: ThemeService.themeModeNotifier,
                    builder: (context, mode, _) {
                      final isDark = mode == AppThemeMode.dark;
                      return Switch(
                        value: isDark,
                        onChanged: (val) async {
                          final newMode = val ? AppThemeMode.dark : AppThemeMode.light;
                          ThemeService.setThemeMode(newMode);
                          await AppScope.of(context).config.saveThemeMode(newMode);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: Icon(Icons.logout, color: AppColors.danger, size: 18),
            label: const Text(
              'ອອກຈາກລະບົບ',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.danger.withValues(alpha: 0.08),
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 8),
        ] else ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _kvList(List<_Kv> rows) {
    return Column(
      children: List.generate(rows.length, (i) {
        final r = rows[i];
        final isLast = i == rows.length - 1;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    fontSize: 13,
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

// — Blue hero card; designed for the light theme so the avatar + name stay
//   prominent against the pale page background.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.goldBright, AppColors.gold, AppColors.goldDim],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

// — Plain dark card matching the theme. -------------------------------------
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: posCardDecoration(radius: kRadiusMd, elevated: false),
      child: child,
    );
  }
}

class _Kv {
  const _Kv(this.key, this.value);
  final String key;
  final String? value;
}