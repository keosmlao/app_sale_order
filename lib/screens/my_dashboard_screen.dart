import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';

class MyDashboardScreen extends StatefulWidget {
  const MyDashboardScreen({super.key});

  @override
  State<MyDashboardScreen> createState() => _MyDashboardScreenState();
}

class _MyDashboardScreenState extends State<MyDashboardScreen> {
  final _moneyFmt = NumberFormat('#,###', 'en_US');
  final _timeFmt = DateFormat('HH:mm');
  Future<MyStats>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.fetchMyStats();
  }

  Future<void> _reload() async {
    setState(() {
      _future = AppScope.of(context).api.fetchMyStats();
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 60),
                _ErrorCard(
                  message: snap.error.toString(),
                  onRetry: _reload,
                ),
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
    final avg =
        today.activeOrders > 0 ? today.activeAmount / today.activeOrders : 0;
    final me = AppScope.of(context).auth.employee;
    final displayName =
        me?.nickname ?? me?.fullnameLo ?? me?.fullnameEn ?? me?.employeeCode ?? '';

    return TabletConstrain(
      maxWidth: 840,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          // Greeting — replaces the AppBar on the dashboard tab.
          FadeInSlide(
            delay: Duration.zero,
            child: _greeting(displayName),
          ),
          const SizedBox(height: 20),
          FadeInSlide(
            delay: const Duration(milliseconds: 100),
            child: _heroCard(today, totalDelta),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 200),
            child: _kpiGrid(today: today, avg: avg.toDouble()),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 300),
            child: _compareStrip(yesterday, totalDelta, ordersDelta),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 400),
            child: _rankPanel(stats.rank),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 500),
            child: _recentPanel(stats.recent),
          ),
        ],
      ),
    );
  }

  // ── Greeting ────────────────────────────────────────────────────────────
  // Quiet "Hello, <name>" + date line. Sets context for the data below
  // without competing with the hero card visually.
  Widget _greeting(String name) {
    final hour = DateTime.now().hour;
    final salute = hour < 12
        ? 'ສະບາຍດີຕອນເຊົ້າ'
        : hour < 18
            ? 'ສະບາຍດີຕອນບ່າຍ'
            : 'ສະບາຍດີຕອນແລງ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? salute : '$salute, $name',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM').format(DateTime.now()),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Hero card ───────────────────────────────────────────────────────────
  // Big "today's sales" number on a calm white surface. The previous gold
  // gradient hero shouted at the user; the number itself is now the visual
  // anchor.
  Widget _heroCard(MyStatsPeriod today, double? delta) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      radius: kRadiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ຍອດຂາຍມື້ນີ້',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (delta != null) _deltaPill(delta),
            ],
          ),
          const SizedBox(height: 14),
          // Big number. FittedBox so very long amounts still fit on small phones.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _moneyFmt.format(today.activeAmount),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ກີບ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroMetric(
                Icons.receipt_long_outlined,
                '${_moneyFmt.format(today.activeOrders)} ບິນ',
              ),
              const SizedBox(width: 16),
              _heroMetric(
                Icons.payments_outlined,
                today.completedCount > 0
                    ? 'ຮັບເງິນ ${today.completedCount}'
                    : 'ຍັງບໍ່ມີຮັບເງິນ',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Compact percent badge — emerald for up, red for down, soft tints.
  Widget _deltaPill(double delta) {
    final positive = delta >= 0;
    final color = positive ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            '${delta.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI grid ────────────────────────────────────────────────────────────

  Widget _kpiGrid({
    required MyStatsPeriod today,
    required double avg,
  }) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            icon: Icons.schedule_outlined,
            tint: AppColors.warning,
            label: 'ລໍຖ້າຮັບເງິນ',
            value: _moneyFmt.format(today.pendingAmount),
            subtitle: '${today.pendingCount} ບິນ',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            icon: Icons.show_chart,
            tint: AppColors.success,
            label: 'ສະເລ່ຍ/ບິນ',
            value: _moneyFmt.format(avg),
            subtitle: '${today.completedCount} ບິນຮັບແລ້ວ',
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color tint,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: kRadiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small tinted icon — restrained, not the focus.
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Yesterday compare strip ─────────────────────────────────────────────

  Widget _compareStrip(
    MyStatsPeriod yesterday,
    double? totalDelta,
    double? ordersDelta,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: kRadiusMd,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.cardElev,
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Icon(
              Icons.history,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ມື້ວານ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_moneyFmt.format(yesterday.activeAmount)} ກີບ · ${yesterday.activeOrders} ບິນ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniDeltaPill('ຍອດ', totalDelta),
              const SizedBox(height: 4),
              _miniDeltaPill('ບິນ', ordersDelta),
            ],
          ),
        ],
      ),
    );
  }

  // Smaller variant of _deltaPill used in the compare strip.
  Widget _miniDeltaPill(String label, double? delta) {
    if (delta == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.cardElev,
          borderRadius: BorderRadius.circular(kRadiusSm / 2),
        ),
        child: Text(
          '$label —',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final positive = delta >= 0;
    final color = positive ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(kRadiusSm / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            positive ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 10,
          ),
          Text(
            '${delta.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Team ranking panel ──────────────────────────────────────────────────

  Widget _rankPanel(MyStatsRank rank) {
    final hasRank = rank.myRank > 0;
    final pct = rank.topTotal > 0
        ? (rank.myTodayTotal / rank.topTotal * 100).clamp(0, 100)
        : 0;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: kRadiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'ອັນດັບໃນທີມ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'ມື້ນີ້',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                // Rank chip — neutral except top-3, which get a subtle gold.
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _rankColor(rank.myRank).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${rank.myRank}',
                        style: TextStyle(
                          color: _rankColor(rank.myRank),
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/${rank.totalSalespeople}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rank.myRank == 1)
                        const Text(
                          '🎉 ເຈົ້າເປັນອັນດັບ 1 ໃນທີມ!',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
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
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(kRadiusSm / 2),
                        child: LinearProgressIndicator(
                          value: (pct / 100).toDouble(),
                          minHeight: 6,
                          backgroundColor: AppColors.cardElev,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _rankColor(rank.myRank),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pct.toStringAsFixed(1)}% ຂອງ Top',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
    if (rank == 1) return const Color(0xFFD97706); // amber-600
    if (rank == 2) return const Color(0xFF6B7280); // slate-500
    if (rank == 3) return const Color(0xFFB45309); // amber-700
    return AppColors.textSecondary;
  }

  // ── Recent orders ──────────────────────────────────────────────────────
  // Bounded ListView.builder (kept from the perf pass earlier in the
  // session) plus the new minimal styling.

  Widget _recentPanel(List<MyStatsRecentOrder> recent) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: kRadiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'ອໍເດີລ່າສຸດຂອງຂ້ອຍ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (recent.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'ຍັງບໍ່ມີ Order',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: (recent.length * 56.0).clamp(56.0, 280.0),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: recent.length,
                itemBuilder: (context, i) {
                  final r = recent[i];
                  final isLast = i == recent.length - 1;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isLast ? Colors.transparent : AppColors.divider,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusColor(r.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.customerName ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '#${r.cartNumber} · ${_timeFmt.format(r.createdAt.toLocal())}',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _moneyFmt.format(r.amount),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

  double? _pctDelta(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : null;
    return ((current - previous) / previous) * 100;
  }
}

// ── Error card ──────────────────────────────────────────────────────────
// Surfaces the network/auth error in plain language with a retry. Used when
// fetchMyStats() rejects (often because the API is unreachable).

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: posCardDecoration(radius: kRadiusLg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 28,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('ລອງໃໝ່'),
          ),
        ],
      ),
    );
  }
}