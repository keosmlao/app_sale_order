import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';

/// The seller's home.
///
/// Every figure comes from /api/me/dashboard, which is the same function
/// the web home page runs. The app used to answer "how did I do today" off
/// the kip total of open orders while the web answered off realised sales
/// in baht — the same person, the same day, two numbers, and no way to
/// tell which was the real one. There is one number now.
///
/// The screen is ordered the way the question is actually asked: what did
/// I sell today, how far is that from my target, where does it put me,
/// then the detail behind it.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _money = NumberFormat('#,###', 'en_US');
  final _dayFmt = DateFormat('d/M');
  Future<HomeDashboard>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.fetchHomeDashboard();
  }

  Future<void> _reload() async {
    final next = AppScope.of(context).api.fetchHomeDashboard();
    setState(() => _future = next);
    await next.catchError((_) => const HomeDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _reload,
          child: FutureBuilder<HomeDashboard>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _Loading();
              }
              if (snap.hasError) {
                return _Failed(error: '${snap.error}', onRetry: _reload);
              }
              return _content(snap.data ?? const HomeDashboard());
            },
          ),
        ),
      ),
    );
  }

  Widget _content(HomeDashboard d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace6),
      children: [
        _Greeting(name: d.employeeName),
        const SizedBox(height: kSpace3),

        // The day, and what it is worth measuring against.
        _TodayCard(data: d, money: _money),
        const SizedBox(height: kSpace3),

        if (d.target.hasTarget) ...[
          _TargetCard(data: d.target, money: _money),
          const SizedBox(height: kSpace3),
        ],

        if (d.rank.ranked) ...[
          _RankCard(rank: d.rank, money: _money),
          const SizedBox(height: kSpace3),
        ],

        _MonthAndQueue(data: d, money: _money),
        const SizedBox(height: kSpace4),

        _Section(title: 'ຍອດຂາຍ 7 ວັນ', child: _Week(daily: d.daily, dayFmt: _dayFmt)),

        if (d.categories.isNotEmpty) ...[
          const SizedBox(height: kSpace4),
          _Section(
            title: 'ຍອດຂາຍຕາມໝວດ',
            trailing: 'ເດືອນນີ້',
            child: _Bars(rows: d.categories, money: _money),
          ),
        ],

        if (d.topItems.isNotEmpty) ...[
          const SizedBox(height: kSpace4),
          _Section(
            title: 'ສິນຄ້າຂາຍດີຂອງຂ້ອຍ',
            trailing: 'ເດືອນນີ້',
            child: _Bars(rows: d.topItems, money: _money),
          ),
        ],

        if (d.recentBills.isNotEmpty) ...[
          const SizedBox(height: kSpace4),
          _Section(
            title: 'ບິນຫຼ້າສຸດຂອງຂ້ອຍ',
            child: _Bills(bills: d.recentBills, money: _money),
          ),
        ],
      ],
    );
  }
}

// ── greeting ────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'ສະບາຍດີຕອນເຊົ້າ'
        : h < 17
        ? 'ສະບາຍດີຕອນບ່າຍ'
        : 'ສະບາຍດີຕອນແລງ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          part,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          name.isEmpty ? '—' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── today ───────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data, required this.money});
  final HomeDashboard data;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final delta = data.dayDelta;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ຍອດຂາຍມື້ນີ້',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              // Against yesterday, and only when yesterday was a day worth
              // comparing to — "up 100%" from nothing says nothing.
              if (delta != null) _Delta(value: delta),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  money.format(data.today.sales),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    color: Colors.white,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ບາດ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'ບິນມື້ນີ້',
                  value: money.format(data.today.bills),
                  unit: 'ບິນ',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Tile(
                  label: 'ມື້ວານ',
                  value: money.format(data.yesterday.sales),
                  unit: 'ບາດ',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            '${(value.abs() * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── target ──────────────────────────────────────────────────────────────

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.data, required this.money});
  final HomeTarget data;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final pct = data.pct;
    final done = pct >= 1;
    final colour = done
        ? AppColors.success
        : pct >= 0.8
        ? AppColors.warning
        : AppColors.primary;
    final left = (data.target - data.sales).clamp(0, double.infinity);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ເປົ້າເດືອນນີ້',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(kRadiusPill),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: colour,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(kRadiusPill),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Figure(
                label: 'ຂາຍໄດ້',
                value: money.format(data.sales),
                colour: colour,
              ),
              const Spacer(),
              _Figure(
                label: 'ເປົ້າ',
                value: money.format(data.target),
                colour: AppColors.textSecondary,
              ),
              const Spacer(),
              _Figure(
                // Once it is met there is no shortfall to report, and
                // "ຍັງຂາດ 0" reads as a failure rather than as done.
                label: done ? 'ເກີນເປົ້າ' : 'ຍັງຂາດ',
                value: money.format(done ? data.sales - data.target : left),
                colour: done ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.colour,
  });
  final String label;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: colour,
            fontFeatures: kTabularFigures,
          ),
        ),
      ],
    );
  }
}

// ── rank ────────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  const _RankCard({required this.rank, required this.money});
  final HomeRank rank;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    Widget slot(String label, HomeRankEntry e) => Expanded(
      child: Column(
        children: [
          _Medal(rank: e.rank),
          const SizedBox(height: 5),
          Text(
            '$label · /${rank.teamSize}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            money.format(e.sales),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ອັນດັບໃນພະແນກ',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              slot('ວັນ', rank.day),
              slot('ອາທິດ', rank.week),
              slot('ເດືອນ', rank.month),
            ],
          ),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    // Gold, silver, bronze — then everyone else, quietly. A rank of 0
    // means no sales in that window at all, so it shows a dash rather
    // than a place nobody holds.
    final (bg, fg) = switch (rank) {
      1 => (const Color(0xFFFFC53D), const Color(0xFF4A3200)),
      2 => (const Color(0xFFCBD5E1), const Color(0xFF1E293B)),
      3 => (const Color(0xFFFB923C), const Color(0xFF4A2000)),
      _ => (AppColors.divider, AppColors.textMuted),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        rank > 0 ? '$rank' : '–',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: fg,
          fontFeatures: kTabularFigures,
        ),
      ),
    );
  }
}

// ── month + cashier queue ───────────────────────────────────────────────

class _MonthAndQueue extends StatelessWidget {
  const _MonthAndQueue({required this.data, required this.money});
  final HomeDashboard data;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Card(
            child: _Stat(
              label: 'ຍອດຂາຍເດືອນນີ້',
              value: money.format(data.month.sales),
              unit: 'ບາດ',
              sub: '${money.format(data.month.bills)} ບິນ',
              colour: AppColors.primary,
              icon: Icons.calendar_month_rounded,
            ),
          ),
        ),
        const SizedBox(width: kSpace3),
        Expanded(
          child: _Card(
            child: _Stat(
              label: 'ລໍຖ້າຮັບເງິນ',
              value: money.format(data.pendingCount),
              unit: 'ບິນ',
              sub: '${money.format(data.pendingAmount)} ກີບ',
              colour: AppColors.warning,
              icon: Icons.schedule_rounded,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    required this.sub,
    required this.colour,
    required this.icon,
  });
  final String label;
  final String value;
  final String unit;
  final String sub;
  final Color colour;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: colour),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── seven days ──────────────────────────────────────────────────────────

class _Week extends StatelessWidget {
  const _Week({required this.daily, required this.dayFmt});
  final List<HomeDailyPoint> daily;
  final DateFormat dayFmt;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const _Empty(text: 'ຍັງບໍ່ມີຍອດຂາຍ');
    final peak = daily.fold<double>(0, (a, p) => p.sales > a ? p.sales : a);
    // A flat week of zeroes would divide by zero and draw nothing; give it
    // a nominal ceiling so the bars render as empty rather than absent.
    final ceiling = peak > 0 ? peak : 1;

    return _Card(
      child: SizedBox(
        height: 132,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: ceiling * 1.18,
            barTouchData: BarTouchData(enabled: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= daily.length) {
                      return const SizedBox.shrink();
                    }
                    final last = i == daily.length - 1;
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        last ? 'ມື້ນີ້' : dayFmt.format(daily[i].day),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: last
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: last
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < daily.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: daily[i].sales,
                      width: 20,
                      borderRadius: BorderRadius.circular(6),
                      // Today stands out; the rest are context.
                      color: i == daily.length - 1
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.28),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: ceiling * 1.18,
                        color: AppColors.divider.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ranked bars (categories, best sellers) ──────────────────────────────

class _Bars extends StatelessWidget {
  const _Bars({required this.rows, required this.money});
  final List<HomeNamedAmount> rows;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final top = rows.fold<double>(0, (a, r) => r.amount > a ? r.amount : a);
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      money.format(rows[i].amount),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(kRadiusPill),
                  child: LinearProgressIndicator(
                    value: top > 0 ? (rows[i].amount / top).clamp(0.0, 1.0) : 0,
                    minHeight: 5,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.primary.withValues(alpha: i == 0 ? 1 : 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── recent bills ────────────────────────────────────────────────────────

class _Bills extends StatelessWidget {
  const _Bills({required this.bills, required this.money});
  final List<HomeBill> bills;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < bills.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bills[i].docNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${bills[i].day} · ${bills[i].items} ລາຍການ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money.format(bills[i].amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── shared pieces ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(
        strokeWidth: 2.6,
        color: AppColors.primary,
      ),
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});
  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    // Inside a RefreshIndicator, so it has to scroll for pull-to-retry to
    // work at all.
    return ListView(
      padding: const EdgeInsets.all(kSpace5),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.cloud_off_rounded,
          size: 34,
          color: AppColors.textSoft,
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'ໂຫລດຂໍ້ມູນບໍ່ສຳເລັດ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('ລອງໃໝ່'),
          ),
        ),
      ],
    );
  }
}
