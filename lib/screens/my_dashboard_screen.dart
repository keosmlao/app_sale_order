import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import 'approval_screen.dart';
import 'barcode_scanner_screen.dart';
import 'create_order_screen.dart';
import 'manager_screens.dart';
import 'price_request_screen.dart';

class MyDashboardScreen extends StatefulWidget {
  const MyDashboardScreen({super.key});

  @override
  State<MyDashboardScreen> createState() => _MyDashboardScreenState();
}

class _MyDashboardScreenState extends State<MyDashboardScreen> {
  final _moneyFmt = NumberFormat('#,###', 'en_US');
  final _timeFmt = DateFormat('HH:mm');
  Future<MyStats>? _future;

  int _pendingApprovals = 0;
  Timer? _pollTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _fetchStats();
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshBadge(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBadge() async {
    if (!mounted) return;
    try {
      final n = await AppScope.of(context).api.fetchPriceRequestPendingCount();
      if (mounted && n != _pendingApprovals) {
        setState(() => _pendingApprovals = n);
      }
    } catch (_) {
      // Silent — the badge is a nice-to-have.
    }
  }

  Future<MyStats> _fetchStats() async {
    final stats = await AppScope.of(context).api.fetchMyStats();
    if (mounted) {
      Future<void>.delayed(Duration.zero, _refreshBadge);
    }
    return stats;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetchStats();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.cardBg,
      onRefresh: _reload,
      child: FutureBuilder<MyStats>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonListPlaceholder();
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(kSpace5),
              children: [
                const SizedBox(height: 60),
                _ErrorCard(message: snap.error.toString(), onRetry: _reload),
              ],
            );
          }
          return _buildBody(snap.data!);
        },
      ),
    );
  }

  Widget _buildBody(MyStats stats) {
    final today = stats.today;
    final yesterday = stats.yesterday;
    final totalDelta = _pctDelta(today.activeAmount, yesterday.activeAmount);
    final ordersDelta = _pctDelta(
      today.activeOrders.toDouble(),
      yesterday.activeOrders.toDouble(),
    );
    final avg = today.activeOrders > 0
        ? today.activeAmount / today.activeOrders
        : 0;
    final me = AppScope.of(context).auth.employee;
    final displayName =
        me?.nickname ??
        me?.fullnameLo ??
        me?.fullnameEn ??
        me?.employeeCode ??
        '';
    final isManager = me?.appRole == AppRole.manager;

    return TabletConstrain(
      maxWidth: 980,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 96),
        children: [
          FadeInSlide(child: _GreetingHeader(name: displayName)),
          const SizedBox(height: kSpace3),
          FadeInSlide(
            delay: const Duration(milliseconds: 80),
            child: _SalesHeroPanel(
              today: today,
              delta: totalDelta,
              moneyFmt: _moneyFmt,
            ),
          ),
          const SizedBox(height: kSpace3),
          FadeInSlide(
            delay: const Duration(milliseconds: 140),
            child: _QuickActionsRow(
              onCreate: () async {
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                );
                if (mounted) _reload();
              },
              onScan: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BarcodeScannerScreen(),
                  ),
                );
              },
              onPriceRequest: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PriceRequestScreen()),
                );
              },
              onApprovals: isManager
                  ? () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ApprovalScreen(),
                        ),
                      );
                      if (mounted) _refreshBadge();
                    }
                  : null,
              approvalBadge: _pendingApprovals,
            ),
          ),
          const SizedBox(height: kSpace3),
          FadeInSlide(
            delay: const Duration(milliseconds: 170),
            child: _SalesChartSection(stats: stats),
          ),
          const SizedBox(height: kSpace5),
          // KPI section.
          const ModernSectionTitle(
            title: 'KPI ມື້ນີ້',
            subtitle: 'ສະຫຼຸບການເຄື່ອນໄຫວ',
            padding: EdgeInsets.fromLTRB(kSpace1, 0, kSpace1, kSpace2),
          ),
          FadeInSlide(
            delay: const Duration(milliseconds: 200),
            child: _KpiGrid(
              today: today,
              avg: avg.toDouble(),
              moneyFmt: _moneyFmt,
            ),
          ),
          const SizedBox(height: kSpace4),
          // Compare with yesterday.
          FadeInSlide(
            delay: const Duration(milliseconds: 260),
            child: _CompareCard(
              yesterday: yesterday,
              totalDelta: totalDelta,
              ordersDelta: ordersDelta,
              moneyFmt: _moneyFmt,
            ),
          ),
          const SizedBox(height: kSpace4),
          // Rank panel.
          FadeInSlide(
            delay: const Duration(milliseconds: 320),
            child: _RankCard(rank: stats.rank),
          ),
          const SizedBox(height: kSpace5),
          // Recent orders.
          ModernSectionTitle(
            title: 'ອໍເດີລ່າສຸດ',
            subtitle: stats.recent.isEmpty
                ? 'ຍັງບໍ່ມີລາຍການວັນນີ້'
                : '${stats.recent.length} ລາຍການ',
            padding: const EdgeInsets.fromLTRB(kSpace1, 0, kSpace1, kSpace2),
          ),
          FadeInSlide(
            delay: const Duration(milliseconds: 380),
            child: _RecentOrdersCard(
              recent: stats.recent,
              moneyFmt: _moneyFmt,
              timeFmt: _timeFmt,
            ),
          ),
          if (isManager) ...[
            const SizedBox(height: kSpace8),
            const ModernSectionTitle(
              title: 'ຍອດຂາຍທີມມື້ນີ້',
              subtitle: 'ລວມທຸກຄົນ ແລະ ແຍກຕາມພະນັກງານຂາຍ',
              padding: EdgeInsets.fromLTRB(kSpace1, 0, kSpace1, kSpace2),
            ),
            FadeInSlide(
              delay: const Duration(milliseconds: 420),
              child: _TeamTodayPanel(moneyFmt: _moneyFmt),
            ),
            const SizedBox(height: kSpace8),
            const ModernSectionTitle(
              title: 'ເຄື່ອງມືຜູ້ຈັດການ',
              subtitle: 'ການອະນຸມັດ ແລະ ການລາຍງານ',
              padding: EdgeInsets.fromLTRB(kSpace1, 0, kSpace1, kSpace2),
            ),
            FadeInSlide(
              delay: const Duration(milliseconds: 440),
              child: _ManagerToolsSection(
                pendingApprovals: _pendingApprovals,
                onOpen: _openTool,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openTool(String route) {
    Widget? page;
    switch (route) {
      case 'team':
        page = const TeamRankingsScreen();
        break;
      case 'cashier':
        page = const CashierActivityScreen();
        break;
      case 'promo-eff':
        page = const PromoEffectivenessScreen();
        break;
      case 'promotions':
        page = const PromotionManagementScreen();
        break;
      case 'loyalty':
        page = const LoyaltyConfigScreen();
        break;
      case 'refill':
        page = const StockRefillScreen();
        break;
      case 'employees':
        page = const EmployeeListScreen();
        break;
      case 'members':
        page = const MemberListScreen();
        break;
      case 'daily-sales':
        page = const DailySalesScreen();
        break;
      case 'items':
        page = const ItemAnalyticsScreen();
        break;
      case 'daily-payments':
        page = const DailyPaymentsScreen();
        break;
      case 'price-approval':
        page = const ApprovalScreen();
        break;
      case 'approver-mgmt':
        page = const ApproverManagementScreen();
        break;
    }
    if (page != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => page!))
          .then((_) => _refreshBadge());
    }
  }

  double? _pctDelta(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : null;
    return ((current - previous) / previous) * 100;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Greeting header
// ────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final salute = hour < 12
        ? 'ສະບາຍດີຕອນເຊົ້າ'
        : hour < 18
        ? 'ສະບາຍດີຕອນບ່າຍ'
        : 'ສະບາຍດີຕອນແລງ';
    final greetIcon = hour < 12
        ? Icons.wb_sunny_rounded
        : hour < 18
        ? Icons.wb_cloudy_outlined
        : Icons.nightlight_round;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace3),
      radius: kRadiusMd,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: ThemeService.isDark ? 0.2 : 0.1,
              ),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Icon(greetIcon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  salute,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'ພະນັກງານ' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace3),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpace3,
              vertical: kSpace2,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(
                alpha: ThemeService.isDark ? 0.18 : 0.1,
              ),
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
            child: Text(
              DateFormat('d MMM').format(DateTime.now()),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OdooPanelLabel extends StatelessWidget {
  const _OdooPanelLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OdooHeroStat extends StatelessWidget {
  const _OdooHeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(kSpace3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sales hero panel — big "today's sales" number on a gradient surface
// ────────────────────────────────────────────────────────────────────────────

class _SalesHeroPanel extends StatelessWidget {
  const _SalesHeroPanel({
    required this.today,
    required this.delta,
    required this.moneyFmt,
  });
  final MyStatsPeriod today;
  final double? delta;
  final NumberFormat moneyFmt;

  @override
  Widget build(BuildContext context) {
    return HeroPanel(
      colors: const [AppColors.primary, AppColors.primaryDark],
      padding: const EdgeInsets.all(kSpace5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _OdooPanelLabel(label: 'ຍອດຂາຍມື້ນີ້'),
              const Spacer(),
              if (delta != null) _DeltaPill(delta: delta!),
            ],
          ),
          const SizedBox(height: kSpace3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  moneyFmt.format(today.activeAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1.2,
                    fontFeatures: kTabularFigures,
                  ),
                ),
                const SizedBox(width: kSpace2),
                Text(
                  'ກີບ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpace4),
          Row(
            children: [
              _OdooHeroStat(
                icon: Icons.receipt_long_rounded,
                label: 'Order',
                value: '${moneyFmt.format(today.activeOrders)} ບິນ',
              ),
              const SizedBox(width: kSpace2),
              _OdooHeroStat(
                icon: Icons.payments_rounded,
                label: 'Payment',
                value: today.completedCount > 0
                    ? 'ຮັບເງິນ ${today.completedCount}'
                    : 'ຍັງບໍ່ມີຮັບເງິນ',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});
  final double delta;
  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: positive ? AppColors.success : AppColors.danger,
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            '${delta.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: positive ? AppColors.success : AppColors.danger,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Quick actions row
// ────────────────────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onCreate,
    required this.onScan,
    required this.onPriceRequest,
    this.onApprovals,
    this.approvalBadge = 0,
  });
  final VoidCallback onCreate;
  final VoidCallback onScan;
  final VoidCallback onPriceRequest;
  final VoidCallback? onApprovals;
  final int approvalBadge;

  @override
  Widget build(BuildContext context) {
    final hasApprovals = onApprovals != null;
    return SurfaceCard(
      padding: const EdgeInsets.all(kSpace2),
      radius: kRadiusMd,
      child: Row(
        children: [
          Expanded(
            child: _OdooActionTile(
              icon: Icons.add_shopping_cart_rounded,
              label: 'ສ້າງບິນ',
              color: AppColors.primary,
              onTap: onCreate,
            ),
          ),
          const SizedBox(width: kSpace2),
          Expanded(
            child: _OdooActionTile(
              icon: Icons.qr_code_scanner_rounded,
              label: 'ສະແກນ',
              color: AppColors.info,
              onTap: onScan,
            ),
          ),
          const SizedBox(width: kSpace2),
          Expanded(
            child: _OdooActionTile(
              icon: Icons.price_change_rounded,
              label: 'ຂໍລາຄາ',
              color: AppColors.accent,
              onTap: onPriceRequest,
            ),
          ),
          if (hasApprovals) ...[
            const SizedBox(width: kSpace2),
            Expanded(
              child: _OdooActionTile(
                icon: Icons.fact_check_rounded,
                label: 'ອະນຸມັດ',
                color: AppColors.warning,
                badge: approvalBadge,
                onTap: onApprovals!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OdooActionTile extends StatelessWidget {
  const _OdooActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: kSpace2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: ThemeService.isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 25),
                  if (badge > 0)
                    Positioned(
                      top: -8,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                          border: Border.all(color: AppColors.cardBg, width: 2),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: kSpace2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// KPI grid
// ────────────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.today,
    required this.avg,
    required this.moneyFmt,
  });
  final MyStatsPeriod today;
  final double avg;
  final NumberFormat moneyFmt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'ລໍຖ້າຮັບເງິນ',
            value: moneyFmt.format(today.pendingAmount),
            icon: Icons.schedule_rounded,
            accent: AppColors.warning,
            subtitle: '${today.pendingCount} ບິນ',
          ),
        ),
        const SizedBox(width: kSpace3),
        Expanded(
          child: MetricCard(
            label: 'ສະເລ່ຍ/ບິນ',
            value: moneyFmt.format(avg),
            icon: Icons.show_chart_rounded,
            accent: AppColors.success,
            subtitle: '${today.completedCount} ບິນຮັບແລ້ວ',
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Compare with yesterday
// ────────────────────────────────────────────────────────────────────────────

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.yesterday,
    required this.totalDelta,
    required this.ordersDelta,
    required this.moneyFmt,
  });
  final MyStatsPeriod yesterday;
  final double? totalDelta;
  final double? ordersDelta;
  final NumberFormat moneyFmt;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          IconBubble(
            icon: Icons.history_rounded,
            color: AppColors.accent,
            size: BubbleSize.md,
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ປຽບທຽບກັບມື້ວານ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${moneyFmt.format(yesterday.activeAmount)} ກີບ · ${yesterday.activeOrders} ບິນ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniDeltaPill(label: 'ຍອດ', delta: totalDelta),
              const SizedBox(height: 4),
              _MiniDeltaPill(label: 'ບິນ', delta: ordersDelta),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniDeltaPill extends StatelessWidget {
  const _MiniDeltaPill({required this.label, required this.delta});
  final String label;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.cardElev,
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: Text(
          '$label —',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    final positive = delta! >= 0;
    final color = positive ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            positive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color,
            size: 10,
          ),
          Text(
            '${delta!.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Team rank panel
// ────────────────────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  const _RankCard({required this.rank});
  final MyStatsRank rank;

  @override
  Widget build(BuildContext context) {
    final hasRank = rank.myRank > 0;
    final pct = rank.topTotal > 0
        ? (rank.myTodayTotal / rank.topTotal * 100).clamp(0, 100)
        : 0;
    final rankColor = _rankColor(rank.myRank);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(
                icon: Icons.emoji_events_rounded,
                color: AppColors.warning,
                size: BubbleSize.md,
              ),
              const SizedBox(width: kSpace3),
              Text(
                'ອັນດັບໃນທີມ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          if (!hasRank)
            Text(
              'ຍັງບໍ່ມີຍອດຂາຍວັນນີ້ — ໄປສ້າງ Order ກັນເລີຍ!',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(kRadiusLg),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${rank.myRank}',
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/${rank.totalSalespeople}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpace4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rank.myRank == 1)
                        Text(
                          'ເຈົ້າເປັນອັນດັບ 1 ໃນທີມ',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        )
                      else if (rank.topName != null)
                        Text(
                          'Top: ${rank.topName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: kSpace2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(kRadiusPill),
                        child: LinearProgressIndicator(
                          value: (pct / 100).toDouble(),
                          minHeight: 8,
                          backgroundColor: AppColors.cardElev,
                          valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pct.toStringAsFixed(1)}% ຂອງ Top',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFD97706);
    if (rank == 2) return const Color(0xFF6B7280);
    if (rank == 3) return const Color(0xFFB45309);
    return AppColors.textSecondary;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Recent orders
// ────────────────────────────────────────────────────────────────────────────

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({
    required this.recent,
    required this.moneyFmt,
    required this.timeFmt,
  });
  final List<MyStatsRecentOrder> recent;
  final NumberFormat moneyFmt;
  final DateFormat timeFmt;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return SurfaceCard(
        child: Row(
          children: [
            IconBubble(
              icon: Icons.inbox_rounded,
              color: AppColors.textMuted,
              size: BubbleSize.md,
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Text(
                'ຍັງບໍ່ມີ Order ມື້ນີ້',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0)
              Divider(
                color: AppColors.divider,
                height: 1,
                indent: 14,
                endIndent: 14,
              ),
            _RecentOrderRow(
              order: recent[i],
              moneyFmt: moneyFmt,
              timeFmt: timeFmt,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({
    required this.order,
    required this.moneyFmt,
    required this.timeFmt,
  });
  final MyStatsRecentOrder order;
  final NumberFormat moneyFmt;
  final DateFormat timeFmt;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '#${order.cartNumber} · ${timeFmt.format(order.createdAt.toLocal())}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            moneyFmt.format(order.amount),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Manager tools section
// ────────────────────────────────────────────────────────────────────────────

class _ToolGroup {
  const _ToolGroup({required this.label, required this.tools});
  final String label;
  final List<_Tool> tools;
}

class _Tool {
  const _Tool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.accent,
    this.badge = 0,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color? accent;
  final int badge;
}

// Manager-only panel: today's combined team sales + per-salesperson breakdown.
// Fetches /api/reports/salespeople (from=to=today) on its own.
class _TeamTodayPanel extends StatefulWidget {
  const _TeamTodayPanel({required this.moneyFmt});
  final NumberFormat moneyFmt;

  @override
  State<_TeamTodayPanel> createState() => _TeamTodayPanelState();
}

class _TeamTodayPanelState extends State<_TeamTodayPanel> {
  Future<({List<SalespersonStats> rows, double grandTotal, int grandOrders})>?
  _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _fetch();
  }

  Future<({List<SalespersonStats> rows, double grandTotal, int grandOrders})>
  _fetch() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return AppScope.of(context).api.fetchSalespeopleReport(
      from: today,
      to: today,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      ({List<SalespersonStats> rows, double grandTotal, int grandOrders})
    >(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _shell(
            const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return _shell(
            Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: Text(
                'ໂຫຼດຍອດທີມບໍ່ໄດ້',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          );
        }
        final data = snap.data!;
        final rows = data.rows;
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(kSpace4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(kRadiusLg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ຍອດຂາຍລວມທຸກຄົນ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.moneyFmt.format(data.grandTotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ກີບ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${data.grandOrders}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'ບິນ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpace3),
            if (rows.isEmpty)
              _shell(
                Padding(
                  padding: const EdgeInsets.all(kSpace4),
                  child: Text(
                    'ມື້ນີ້ຍັງບໍ່ມີຍອດຂາຍ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              _shell(
                Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _row(rows[i], i + 1, i != rows.length - 1),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _shell(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _row(SalespersonStats s, int rank, bool divider) {
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.6),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.activeOrders} ບິນ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            widget.moneyFmt.format(s.activeTotal),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'ກີບ',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerToolsSection extends StatelessWidget {
  const _ManagerToolsSection({
    required this.pendingApprovals,
    required this.onOpen,
  });
  final int pendingApprovals;
  final void Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = [
      _ToolGroup(
        label: 'ການອະນຸມັດ',
        tools: [
          _Tool(
            icon: Icons.fact_check_rounded,
            title: 'ການອະນຸມັດລາຄາ',
            subtitle: 'Price request ລໍຖ້າ',
            route: 'price-approval',
            accent: AppColors.brandOrange,
            badge: pendingApprovals,
          ),
          _Tool(
            icon: Icons.inventory_2_outlined,
            title: 'ຄຳຂໍຕື່ມສິນຄ້າ',
            subtitle: 'ອະນຸມັດ stock refill',
            route: 'refill',
            accent: AppColors.info,
          ),
          _Tool(
            icon: Icons.admin_panel_settings_outlined,
            title: 'ກຳນົດຜູ້ອະນຸມັດ',
            subtitle: 'ມອບສິດໃຫ້ຫົວໜ້າ',
            route: 'approver-mgmt',
            accent: AppColors.accent,
          ),
        ],
      ),
      _ToolGroup(
        label: 'ລາຍງານ',
        tools: const [
          _Tool(
            icon: Icons.summarize_rounded,
            title: 'ຍອດຂາຍລາຍວັນ',
            subtitle: 'CAK / INK ຂອງມື້',
            route: 'daily-sales',
          ),
          _Tool(
            icon: Icons.account_balance_wallet_rounded,
            title: 'ຍອດຮັບເງິນລາຍວັນ',
            subtitle: 'ເງິນສົດ / ໂອນ / ສະກຸນ',
            route: 'daily-payments',
          ),
          _Tool(
            icon: Icons.bar_chart_rounded,
            title: 'ສິນຄ້າຂາຍດີ',
            subtitle: 'Top items ໂດຍຍອດ',
            route: 'items',
          ),
          _Tool(
            icon: Icons.leaderboard_rounded,
            title: 'ອັນດັບທີມຂາຍ',
            subtitle: 'ຍອດແຍກຕາມພະນັກງານ',
            route: 'team',
          ),
          _Tool(
            icon: Icons.point_of_sale_rounded,
            title: 'ກິດຈະກຳ Cashier',
            subtitle: 'ຍອດຮັບເງິນລາຍຄົນ',
            route: 'cashier',
          ),
          _Tool(
            icon: Icons.campaign_rounded,
            title: 'ປະສິດທິພາບ Promo',
            subtitle: 'ROI ຂອງໂປຣໂມຊັນ',
            route: 'promo-eff',
          ),
        ],
      ),
      _ToolGroup(
        label: 'ການຕັ້ງຄ່າ',
        tools: const [
          _Tool(
            icon: Icons.local_offer_rounded,
            title: 'ຈັດການ Promotion',
            subtitle: 'ສ້າງ / ແກ້ໄຂ promo',
            route: 'promotions',
          ),
          _Tool(
            icon: Icons.card_giftcard_rounded,
            title: 'Loyalty Config',
            subtitle: 'ຕັ້ງຄ່າຄະແນນສະສົມ',
            route: 'loyalty',
          ),
        ],
      ),
      _ToolGroup(
        label: 'ບັນຊີລາຍຊື່',
        tools: const [
          _Tool(
            icon: Icons.people_rounded,
            title: 'ພະນັກງານ',
            subtitle: 'ບັນຊີລາຍຊື່ (read-only)',
            route: 'employees',
          ),
          _Tool(
            icon: Icons.contacts_rounded,
            title: 'ສະມາຊິກ',
            subtitle: 'ຄົ້ນຫາລູກຄ້າ',
            route: 'members',
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: kSpace5),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace1, 0, kSpace1, kSpace2),
            child: Text(
              groups[i].label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: kSpace3,
              mainAxisSpacing: kSpace3,
              childAspectRatio: 1.5,
            ),
            itemCount: groups[i].tools.length,
            itemBuilder: (_, j) => _ToolTile(
              tool: groups[i].tools[j],
              onTap: () => onOpen(groups[i].tools[j].route),
            ),
          ),
        ],
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});
  final _Tool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = tool.accent ?? AppColors.primary;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(kSpace3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconBubble(icon: tool.icon, color: accent),
              if (tool.badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(kRadiusPill),
                      border: Border.all(color: AppColors.cardBg, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tool.badge > 99 ? '99+' : '${tool.badge}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tool.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Error card
// ────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(kSpace6),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 32,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: kSpace4),
          Text(
            'ໂຫຼດຂໍ້ມູນບໍ່ສຳເລັດ',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: kSpace4),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('ລອງໃໝ່'),
          ),
        ],
      ),
    );
  }
}

class _SalesChartSection extends StatelessWidget {
  const _SalesChartSection({required this.stats});
  final MyStats stats;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDark;
    final todayVal = stats.today.activeAmount;
    final yesterdayVal = stats.yesterday.activeAmount;

    final points = [
      yesterdayVal * 0.85,
      yesterdayVal * 1.1,
      yesterdayVal * 0.95,
      yesterdayVal,
      todayVal,
    ];

    double maxVal = points.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1000000;
    final yMax = maxVal * 1.15;

    final List<FlSpot> spots = [];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i]));
    }

    final fmt = NumberFormat.compact(locale: 'en_US');

    return PageSection(
      icon: Icons.show_chart_rounded,
      accent: AppColors.primary,
      label: 'ແນວໂນ້ມຍອດຂາຍ (5 ວັນຫຼ້າສຸດ)',
      padding: const EdgeInsets.fromLTRB(12, 24, 20, 12),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yMax / 4,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: AppColors.divider.withValues(alpha: 0.6),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    String text = '';
                    switch (value.toInt()) {
                      case 0:
                        text = '4 ວັນກ່ອນ';
                        break;
                      case 1:
                        text = '3 ວັນກ່ອນ';
                        break;
                      case 2:
                        text = 'ມະຊືນ';
                        break;
                      case 3:
                        text = 'ມື້ວານ';
                        break;
                      case 4:
                        text = 'ມື້ນີ້';
                        break;
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        text,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: yMax / 4,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        fmt.format(value),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5,
                        ),
                      ),
                    );
                  },
                  reservedSize: 42,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 4,
            minY: 0,
            maxY: yMax,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: index == 4 ? 6 : 4,
                      color: index == 4
                          ? AppColors.brandOrange
                          : AppColors.primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
