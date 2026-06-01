// Manager-facing screens — bundled together because each is small and they
// share supporting widgets (date-range picker, stat card, loading scaffold).
// Wire up via Profile → "ສຳລັບຜູ້ຈັດການ".

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/approver_delegation.dart';

// ─────────────────────────────────────────────────────────────────────────
// Manager Hub — the launcher screen the user reaches from Profile.
// ─────────────────────────────────────────────────────────────────────────

class ManagerHubScreen extends StatelessWidget {
  const ManagerHubScreen({super.key});

  static const _features = <_Feature>[
    _Feature(
      icon: Icons.leaderboard_rounded,
      title: 'ອັນດັບທີມຂາຍ',
      subtitle: 'ຍອດແຍກຕາມພະນັກງານ',
      route: 'team',
      accent: AppColors.warning,
      disabled: false,
    ),
    _Feature(
      icon: Icons.point_of_sale_rounded,
      title: 'ກິດຈະກຳ Cashier',
      subtitle: 'ຍອດຮັບເງິນລາຍຄົນ',
      route: 'cashier',
      accent: AppColors.info,
    ),
    _Feature(
      icon: Icons.campaign_rounded,
      title: 'ປະສິດທິພາບ Promo',
      subtitle: 'ROI ຂອງໂປຣໂມຊັນ',
      route: 'promo-eff',
      accent: AppColors.brandOrange,
    ),
    _Feature(
      icon: Icons.local_offer_rounded,
      title: 'ຈັດການ Promotion',
      subtitle: 'ສ້າງ / ແກ້ໄຂ promo',
      route: 'promotions',
      accent: AppColors.brandOrange,
    ),
    _Feature(
      icon: Icons.card_giftcard_rounded,
      title: 'Loyalty Config',
      subtitle: 'ຕັ້ງຄ່າຄະແນນສະສົມ',
      route: 'loyalty',
      accent: AppColors.accent,
    ),
    _Feature(
      icon: Icons.inventory_2_rounded,
      title: 'ຄຳຂໍຕື່ມສິນຄ້າ',
      subtitle: 'ອະນຸມັດ stock refill',
      route: 'refill',
      accent: AppColors.primary,
    ),
    _Feature(
      icon: Icons.summarize_rounded,
      title: 'ຍອດຂາຍລາຍວັນ',
      subtitle: 'CAK / INK ຂອງມື້',
      route: 'daily-sales',
      accent: AppColors.success,
    ),
    _Feature(
      icon: Icons.bar_chart_rounded,
      title: 'ສິນຄ້າຂາຍດີ',
      subtitle: 'Top items ໂດຍຍອດ',
      route: 'items',
      accent: AppColors.info,
    ),
    _Feature(
      icon: Icons.account_balance_wallet_rounded,
      title: 'ຍອດຮັບເງິນລາຍວັນ',
      subtitle: 'ເງິນສົດ / ໂອນ / ສະກຸນ',
      route: 'daily-payments',
      accent: AppColors.success,
    ),
    _Feature(
      icon: Icons.people_rounded,
      title: 'ພະນັກງານ',
      subtitle: 'ບັນຊີລາຍຊື່ (read-only)',
      route: 'employees',
      accent: Color(0xFF475569),
    ),
    _Feature(
      icon: Icons.contacts_rounded,
      title: 'ສະມາຊິກ',
      subtitle: 'ຄົ້ນຫາລູກຄ້າ',
      route: 'members',
      accent: AppColors.accent,
    ),
  ];

  void _open(BuildContext context, _Feature f) {
    if (f.disabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${f.title} ຍັງບໍ່ມີ API — ກຳລັງພັດທະນາ')),
      );
      return;
    }
    Widget page;
    switch (f.route) {
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
      default:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('ສຳລັບຜູ້ຈັດການ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: TabletConstrain(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                kSpace4, kSpace3, kSpace4, kSpace8),
            children: [
              FadeInSlide(
                child: HeroPanel(
                  colors: const [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(kRadiusMd),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ສູນກາງຜູ້ຈັດການ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ລາຍງານ · ການອະນຸມັດ · ການຕັ້ງຄ່າ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: kSpace5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: kSpace3,
                  mainAxisSpacing: kSpace3,
                  childAspectRatio: 1.4,
                ),
                itemCount: _features.length,
                itemBuilder: (context, i) {
                  final f = _features[i];
                  return FadeInSlide(
                    delay: Duration(milliseconds: 80 + i * 40),
                    child: _FeatureTile(
                        feature: f, onTap: () => _open(context, f)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.accent,
    this.disabled = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color? accent;
  final bool disabled;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature, required this.onTap});
  final _Feature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = feature.disabled
        ? AppColors.textMuted
        : (feature.accent ?? AppColors.primary);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(kSpace3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconBubble(icon: feature.icon, color: c),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                feature.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: feature.disabled
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                feature.subtitle,
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

// ─────────────────────────────────────────────────────────────────────────
// Shared widgets used by the screens below.
// ─────────────────────────────────────────────────────────────────────────

// Inline date-range editor + apply button. Replaces the verbose
// per-screen filter rows that earlier prototypes used.
class _DateRangeBar extends StatelessWidget {
  const _DateRangeBar({
    required this.from,
    required this.to,
    required this.onChanged,
  });
  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onChanged;

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: from, end: to),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) onChanged(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d/M/yyyy');
    return InkWell(
      onTap: () => _pickRange(context),
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardElev,
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${fmt.format(from)}  →  ${fmt.format(to)}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// Centred empty / error / loading state. Each report uses this to keep its
// async wrapping consistent.
class _StateView extends StatelessWidget {
  const _StateView.empty({this.message})
      : icon = Icons.inbox_outlined,
        isError = false;
  const _StateView.error(this.message)
      : icon = Icons.cloud_off_outlined,
        isError = true;
  final IconData icon;
  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isError ? AppColors.danger : AppColors.textMuted)
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isError ? AppColors.danger : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message ?? (isError ? 'ໂຫຼດຂໍ້ມູນບໍ່ສຳເລັດ' : 'ບໍ່ມີຂໍ້ມູນ'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? AppColors.danger : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 1) Team rankings — /api/reports/salespeople
// ─────────────────────────────────────────────────────────────────────────

class TeamRankingsScreen extends StatefulWidget {
  const TeamRankingsScreen({super.key});
  @override
  State<TeamRankingsScreen> createState() => _TeamRankingsScreenState();
}

class _TeamRankingsScreenState extends State<TeamRankingsScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  late DateTime _from;
  late DateTime _to;
  Future<({List<SalespersonStats> rows, double grandTotal, int grandOrders})>?
      _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day);
    _to = _from;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<({List<SalespersonStats> rows, double grandTotal, int grandOrders})>
      _load() {
    return AppScope.of(context)
        .api
        .fetchSalespeopleReport(from: _from, to: _to);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ອັນດັບທີມຂາຍ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _DateRangeBar(
              from: _from,
              to: _to,
              onChanged: (f, t) {
                _from = f;
                _to = t;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<
                ({List<SalespersonStats> rows, double grandTotal, int grandOrders})>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonListPlaceholder();
                }
                if (snap.hasError) {
                  return _StateView.error(snap.error.toString());
                }
                final data = snap.data!;
                if (data.rows.isEmpty) {
                  return const _StateView.empty();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      GradientHero(
                        child: Row(
                          children: [
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ຍອດລວມທີມ',
                                value: '${_fmt.format(data.grandTotal)} ກີບ',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ບິນທີມ',
                                value: '${_fmt.format(data.grandOrders)} ບິນ',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < data.rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _SalespersonRow(rank: i + 1, row: data.rows[i], fmt: _fmt),
                      ],
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
}

class _SalespersonRow extends StatelessWidget {
  const _SalespersonRow({
    required this.rank,
    required this.row,
    required this.fmt,
  });
  final int rank;
  final SalespersonStats row;
  final NumberFormat fmt;

  Color _rankTint() {
    if (rank == 1) return const Color(0xFFD97706);
    if (rank == 2) return const Color(0xFF6B7280);
    if (rank == 3) return const Color(0xFFB45309);
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: posCardDecoration(radius: kRadiusMd),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankTint().withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                color: _rankTint(),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
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
                  '${row.activeOrders} ບິນ · ສະເລ່ຍ ${fmt.format(row.avgOrderValue)}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt.format(row.activeTotal),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                'ກີບ',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Hero-friendly variant: white text on the emerald gradient backdrop.
// Used by report screens that put a totals card at the top.
class _HeroStatColumn extends StatelessWidget {
  const _HeroStatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 2) Cashier activity — /api/reports/shift-summary
// ─────────────────────────────────────────────────────────────────────────

class CashierActivityScreen extends StatefulWidget {
  const CashierActivityScreen({super.key});
  @override
  State<CashierActivityScreen> createState() => _CashierActivityScreenState();
}

class _CashierActivityScreenState extends State<CashierActivityScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  late DateTime _from;
  late DateTime _to;
  Future<List<CashierShiftRow>>? _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day);
    _to = _from;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<CashierShiftRow>> _load() =>
      AppScope.of(context).api.fetchCashierShifts(from: _from, to: _to);

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ກິດຈະກຳ Cashier')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _DateRangeBar(
              from: _from,
              to: _to,
              onChanged: (f, t) {
                _from = f;
                _to = t;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CashierShiftRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonListPlaceholder();
                }
                if (snap.hasError) return _StateView.error(snap.error.toString());
                final rows = snap.data ?? const [];
                if (rows.isEmpty) return const _StateView.empty();
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      GradientHero(
                        child: Row(
                          children: [
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ຍອດຮັບເງິນລວມ',
                                value:
                                    '${_fmt.format(rows.fold<double>(0, (s, r) => s + r.totalKip))} ກີບ',
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 36,
                                color:
                                    Colors.white.withValues(alpha: 0.3)),
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ຈຳນວນບິນ',
                                value: _fmt.format(rows.fold<int>(
                                    0, (s, r) => s + r.billCount)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _CashierRow(row: rows[i], fmt: _fmt),
                      ],
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
}

class _CashierRow extends StatelessWidget {
  const _CashierRow({required this.row, required this.fmt});
  final CashierShiftRow row;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: posCardDecoration(radius: kRadiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.cashierName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.day} · ${row.billCount} ບິນ${row.voidedCount > 0 ? " · void ${row.voidedCount}" : ""}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fmt.format(row.totalKip),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          // Channel breakdown.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _kvChip('ເງິນສົດ', fmt.format(row.cashKip), AppColors.success),
              _kvChip('ໂອນ', fmt.format(row.transferKip), AppColors.info),
              if (row.redeemedKip > 0)
                _kvChip('ແຕ້ມ', fmt.format(row.redeemedKip), AppColors.primary),
              if (row.promoKip > 0)
                _kvChip('Promo', fmt.format(row.promoKip), AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kvChip(String label, String value, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 3) Promo effectiveness — /api/reports/promo-effectiveness
// ─────────────────────────────────────────────────────────────────────────

class PromoEffectivenessScreen extends StatefulWidget {
  const PromoEffectivenessScreen({super.key});
  @override
  State<PromoEffectivenessScreen> createState() =>
      _PromoEffectivenessScreenState();
}

class _PromoEffectivenessScreenState extends State<PromoEffectivenessScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  late DateTime _from;
  late DateTime _to;
  Future<List<PromoEffectivenessRow>>? _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(const Duration(days: 30));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<PromoEffectivenessRow>> _load() =>
      AppScope.of(context).api.fetchPromoEffectiveness(from: _from, to: _to);

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ປະສິດທິພາບ Promo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _DateRangeBar(
              from: _from,
              to: _to,
              onChanged: (f, t) {
                _from = f;
                _to = t;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PromoEffectivenessRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonListPlaceholder();
                }
                if (snap.hasError) return _StateView.error(snap.error.toString());
                final rows = snap.data ?? const [];
                if (rows.isEmpty) return const _StateView.empty();
                final activeCount = rows.where((r) => r.isActive).length;
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      GradientHero(
                        child: Row(
                          children: [
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ໂປຣທັງໝົດ',
                                value: '${rows.length}',
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 36,
                                color:
                                    Colors.white.withValues(alpha: 0.3)),
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ກຳລັງເປີດ',
                                value: '$activeCount',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Builder(
                          builder: (_) {
                            final r = rows[i];
                            return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: posCardDecoration(radius: kRadiusMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.promoName,
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
                                        '${r.promoType ?? '—'} · ${r.billCount} ບິນ · ${r.lineCount} ລາຍການ',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (r.isActive
                                            ? AppColors.success
                                            : AppColors.textMuted)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(
                                        kRadiusXl),
                                  ),
                                  child: Text(
                                    r.isActive ? 'ເປີດ' : 'ປິດ',
                                    style: TextStyle(
                                      color: r.isActive
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(height: 1, color: AppColors.divider),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ສ່ວນຫຼຸດທີ່ໃຫ້',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${_fmt.format(r.totalDiscountKip)} ກີບ',
                                        style: TextStyle(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ຍອດທີ່ສ້າງ',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${_fmt.format(r.totalKip)} ກີບ',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
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
                          },
                        ),
                      ],
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
}

// ─────────────────────────────────────────────────────────────────────────
// 4) Promotion management — list + view (create/edit out of scope here;
// shows the list and lets manager toggle active).
// ─────────────────────────────────────────────────────────────────────────

class PromotionManagementScreen extends StatefulWidget {
  const PromotionManagementScreen({super.key});
  @override
  State<PromotionManagementScreen> createState() =>
      _PromotionManagementScreenState();
}

class _PromotionManagementScreenState
    extends State<PromotionManagementScreen> {
  Future<List<Promotion>>? _future;
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Promotion>> _load() =>
      AppScope.of(context).api.listPromotions();

  void _refresh() => setState(() => _future = _load());

  Future<void> _toggle(Promotion p) async {
    setState(() => _busyId = p.id);
    try {
      await AppScope.of(context).api.updatePromotion(
        p.id,
        {'isActive': !p.isActive},
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ປ່ຽນບໍ່ສຳເລັດ: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ຈັດການ Promotion')),
      body: FutureBuilder<List<Promotion>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonListPlaceholder();
          }
          if (snap.hasError) return _StateView.error(snap.error.toString());
          final rows = snap.data ?? const [];
          if (rows.isEmpty) return const _StateView.empty();
          final activeCount = rows.where((p) => p.isActive).length;
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                GradientHero(
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroStatColumn(
                          label: 'Promotion ທັງໝົດ',
                          value: '${rows.length}',
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withValues(alpha: 0.3)),
                      Expanded(
                        child: _HeroStatColumn(
                          label: 'ກຳລັງເປີດ',
                          value: '$activeCount',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final p = rows[i];
                    final busy = _busyId == p.id;
                    return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: posCardDecoration(radius: kRadiusMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.promoType,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (busy)
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            )
                          else
                            Switch(
                              value: p.isActive,
                              onChanged: (_) => _toggle(p),
                            ),
                        ],
                      ),
                      if (p.note != null && p.note!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          p.note!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 5) Loyalty config — read + update
// ─────────────────────────────────────────────────────────────────────────

class LoyaltyConfigScreen extends StatefulWidget {
  const LoyaltyConfigScreen({super.key});
  @override
  State<LoyaltyConfigScreen> createState() => _LoyaltyConfigScreenState();
}

class _LoyaltyConfigScreenState extends State<LoyaltyConfigScreen> {
  final _earnCtl = TextEditingController();
  final _redeemCtl = TextEditingController();
  final _minRedeemCtl = TextEditingController();
  final _pointNameCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _earnCtl.dispose();
    _redeemCtl.dispose();
    _minRedeemCtl.dispose();
    _pointNameCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await AppScope.of(context).api.fetchLoyaltyConfigManager();
      _earnCtl.text = c.earnKipPerPoint.toStringAsFixed(0);
      _redeemCtl.text = c.redeemPointsPerKip.toString();
      _minRedeemCtl.text = c.minRedeemPoints.toString();
      _pointNameCtl.text = c.pointName;
      _noteCtl.text = c.note ?? '';
      _isActive = c.isActive;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppScope.of(context).api.updateLoyaltyConfig(
            earnKipPerPoint: double.tryParse(_earnCtl.text),
            redeemPointsPerKip: double.tryParse(_redeemCtl.text),
            minRedeemPoints: int.tryParse(_minRedeemCtl.text),
            pointName: _pointNameCtl.text.trim(),
            note: _noteCtl.text.trim(),
            isActive: _isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ບັນທຶກສຳເລັດ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ບັນທຶກບໍ່ສຳເລັດ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Config')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _StateView.error(_error)
              : SafeArea(
                  child: TabletConstrain(
                    maxWidth: 520,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      children: [
                        SwitchListTile(
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          title: const Text('ເປີດໃຊ້ Loyalty'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _earnCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ກີບຕໍ່ 1 ຄະແນນ (ຄິດໄດ້)',
                            prefixIcon: Icon(Icons.trending_up),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _redeemCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ຄະແນນຕໍ່ 1 ກີບ (ແລກໄດ້)',
                            prefixIcon: Icon(Icons.swap_horiz),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _minRedeemCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ຄະແນນຕ່ຳສຸດເພື່ອແລກ',
                            prefixIcon: Icon(Icons.vertical_align_bottom),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pointNameCtl,
                          decoration: const InputDecoration(
                            labelText: 'ຊື່ຄະແນນ',
                            hintText: 'ແຕ້ມສະສົມ',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteCtl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ໝາຍເຫດ',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.save_outlined),
                          label: const Text('ບັນທຶກ'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 6) Stock refill — approve workflow
// ─────────────────────────────────────────────────────────────────────────

class StockRefillScreen extends StatefulWidget {
  const StockRefillScreen({super.key});
  @override
  State<StockRefillScreen> createState() => _StockRefillScreenState();
}

class _StockRefillScreenState extends State<StockRefillScreen> {
  Future<({
    bool canApprove,
    bool canCreate,
    List<StockRefillItem> items,
    List<StockRefillRequest> requests,
  })>? _future;
  final _fmt = NumberFormat('#,###.##', 'en_US');
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<({
    bool canApprove,
    bool canCreate,
    List<StockRefillItem> items,
    List<StockRefillRequest> requests,
  })> _load() => AppScope.of(context).api.fetchStockRefill();

  void _refresh() => setState(() => _future = _load());

  Future<void> _act(StockRefillRequest r, String action) async {
    setState(() => _busyId = r.id);
    try {
      await AppScope.of(context).api.actOnStockRefill(r.id, action);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ປະຕິບັດບໍ່ສຳເລັດ: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ຄຳຂໍຕື່ມສິນຄ້າ')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonListPlaceholder();
          }
          if (snap.hasError) return _StateView.error(snap.error.toString());
          final data = snap.data!;
          final hasNothing = data.items.isEmpty && data.requests.isEmpty;
          if (hasNothing) return const _StateView.empty();
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (data.requests.isNotEmpty) ...[
                  const _SectionHeading('ຄຳຂໍລໍຖ້າຕັດສິນ'),
                  for (final r in data.requests) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: posCardDecoration(radius: kRadiusMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.itemName ?? r.itemCode,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.10),
                                    borderRadius:
                                        BorderRadius.circular(kRadiusXl),
                                  ),
                                  child: Text(
                                    r.status,
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ຄັງ ${r.warehouseCode} · ຂໍ ${_fmt.format(r.requestedQty)}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (r.reason != null && r.reason!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'ເຫດຜົນ: ${r.reason!}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (data.canApprove &&
                                r.status == 'pending') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _busyId == r.id
                                          ? null
                                          : () => _act(r, 'reject'),
                                      child: const Text('ປະຕິເສດ'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _busyId == r.id
                                          ? null
                                          : () => _act(r, 'approve'),
                                      child: _busyId == r.id
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('ອະນຸມັດ'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                if (data.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _SectionHeading('ສິນຄ້າທີ່ໃກ້ໝົດ/ໝົດ'),
                  for (final it in data.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: posCardDecoration(radius: kRadiusMd),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.itemName,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${it.itemCode} · ຄັງ ${it.warehouseCode}',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _fmt.format(it.currentBalance),
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'ຕ່ຳສຸດ ${_fmt.format(it.minimumBalance)}',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 7) Employee list (read-only)
// ─────────────────────────────────────────────────────────────────────────

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});
  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  Future<List<Employee>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.listEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ພະນັກງານ')),
      body: FutureBuilder<List<Employee>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonListPlaceholder();
          }
          if (snap.hasError) return _StateView.error(snap.error.toString());
          final rows = snap.data ?? const [];
          if (rows.isEmpty) return const _StateView.empty();
          final managerCount =
              rows.where((e) => e.appRole == AppRole.manager).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GradientHero(
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroStatColumn(
                          label: 'ພະນັກງານ',
                          value: '${rows.length}',
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withValues(alpha: 0.3)),
                      Expanded(
                        child: _HeroStatColumn(
                          label: 'Manager',
                          value: '$managerCount',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = rows[i];
                    final name = e.nickname ??
                        e.fullnameLo ??
                        e.fullnameEn ??
                        e.employeeCode ??
                        '—';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: posCardDecoration(radius: kRadiusMd),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardElev,
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e.employeeCode ?? '—'} · ${e.positionCode ?? ''}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (e.appRole == AppRole.manager)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(kRadiusXl),
                        ),
                        child: const Text(
                          'manager',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 7.5) Approver delegation — manager picks which heads can approve
//      price requests on their behalf. Backend is mocked for now via
//      ApproverDelegationService (in-memory).
// ─────────────────────────────────────────────────────────────────────────

class ApproverManagementScreen extends StatefulWidget {
  const ApproverManagementScreen({super.key});
  @override
  State<ApproverManagementScreen> createState() =>
      _ApproverManagementScreenState();
}

class _ApproverManagementScreenState extends State<ApproverManagementScreen> {
  Future<List<Employee>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.listEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ກຳນົດຜູ້ອະນຸມັດ')),
      body: FutureBuilder<List<Employee>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonListPlaceholder();
          }
          if (snap.hasError) {
            return _StateView.error(snap.error.toString());
          }
          // Only "head" employees are candidates — managers already
          // approve by default, salespeople/PC don't need to.
          final heads = (snap.data ?? const <Employee>[])
              .where((e) => e.appRole == AppRole.head)
              .toList();
          if (heads.isEmpty) {
            return const _StateView.empty(
              message: 'ບໍ່ມີຫົວໜ້າໜ່ວຍງານໃນລະບົບ',
            );
          }
          final delegatedCount = heads
              .where((e) =>
                  ApproverDelegationService.isDelegated(e.employeeCode ?? ''))
              .length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              GradientHero(
                child: Row(
                  children: [
                    Expanded(
                      child: _HeroStatColumn(
                        label: 'ຫົວໜ້າທັງໝົດ',
                        value: '${heads.length}',
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withValues(alpha: 0.3)),
                    Expanded(
                      child: _HeroStatColumn(
                        label: 'ມອບສິດແລ້ວ',
                        value: '$delegatedCount',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InfoBanner(
                icon: Icons.info_outline,
                text:
                    'ເລືອກຫົວໜ້າທີ່ສາມາດອະນຸມັດລາຄາແທນຜູ້ຈັດການ. ການປ່ຽນແປງເກັບໄວ້ໃນເຄື່ອງ (mock).',
              ),
              const SizedBox(height: 12),
              ...heads.map((e) {
                final code = e.employeeCode ?? '';
                final delegated = ApproverDelegationService.isDelegated(code);
                final name = e.displayName;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: posCardDecoration(radius: kRadiusMd),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: delegated
                              ? AppColors.primary50
                              : AppColors.cardElev,
                          borderRadius: BorderRadius.circular(kRadiusMd),
                        ),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: delegated
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${e.employeeCode ?? '—'} · ${e.positionCode ?? 'ຫົວໜ້າ'}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: delegated,
                        onChanged: code.isEmpty
                            ? null
                            : (val) {
                                setState(() {
                                  ApproverDelegationService.setDelegated(
                                    code,
                                    val,
                                  );
                                });
                              },
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 8) Member list (read-only, search)
// ─────────────────────────────────────────────────────────────────────────

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});
  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final _searchCtl = TextEditingController();
  final _fmt = NumberFormat('#,###', 'en_US');
  Future<List<MemberSummary>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.searchMembers();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() {
      _future = AppScope.of(context).api.searchMembers(q: q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ສະມາຊິກ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: GradientHero(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.contacts_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.95)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtl,
                      onSubmitted: _search,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'ຄົ້ນຫາສະມາຊິກ',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_searchCtl.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 18),
                      onPressed: () {
                        _searchCtl.clear();
                        _search('');
                      },
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MemberSummary>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonListPlaceholder();
                }
                if (snap.hasError) return _StateView.error(snap.error.toString());
                final rows = snap.data ?? const [];
                if (rows.isEmpty) return const _StateView.empty();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = rows[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: posCardDecoration(radius: kRadiusMd),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${m.phone ?? '—'} · ${m.tier ?? '—'}',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_fmt.format(m.pointsBalance)} pt',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${_fmt.format(m.totalSpent)} ກີບ',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 9) Daily sales report — /api/reports/daily-sales
// ─────────────────────────────────────────────────────────────────────────

class DailySalesScreen extends StatefulWidget {
  const DailySalesScreen({super.key});
  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  late DateTime _date;
  Future<({
    String date,
    DailySalesTotals totals,
    List<DailySalesCurrency> currencies,
    List<DailySalesSalesperson> salespeople,
    List<DailySalesRow> rows,
  })>? _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _date = DateTime(today.year, today.month, today.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<({
    String date,
    DailySalesTotals totals,
    List<DailySalesCurrency> currencies,
    List<DailySalesSalesperson> salespeople,
    List<DailySalesRow> rows,
  })> _load() =>
      AppScope.of(context).api.fetchDailySales(date: _date);

  void _refresh() => setState(() => _future = _load());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      _date = picked;
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ຍອດຂາຍລາຍວັນ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardElev,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_date),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonListPlaceholder();
                }
                if (snap.hasError) return _StateView.error(snap.error.toString());
                final data = snap.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      GradientHero(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeroStatColumn(
                              label: 'ຍອດລວມ',
                              value: '${_fmt.format(data.totals.total)} ບາດ',
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _HeroStatColumn(
                                    label: 'CAK',
                                    value:
                                        '${_fmt.format(data.totals.cakTotal)} (${data.totals.cakCount})',
                                  ),
                                ),
                                Container(
                                    width: 1,
                                    height: 36,
                                    color:
                                        Colors.white.withValues(alpha: 0.3)),
                                Expanded(
                                  child: _HeroStatColumn(
                                    label: 'INK',
                                    value:
                                        '${_fmt.format(data.totals.inkTotal)} (${data.totals.inkCount})',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _HeroStatColumn(
                                    label: 'ກ່ອນ VAT',
                                    value: _fmt.format(data.totals.totalBeforeVat),
                                  ),
                                ),
                                Container(
                                    width: 1,
                                    height: 36,
                                    color:
                                        Colors.white.withValues(alpha: 0.3)),
                                Expanded(
                                  child: _HeroStatColumn(
                                    label: 'VAT',
                                    value: _fmt.format(data.totals.totalVat),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (data.salespeople.isNotEmpty) ...[
                        const _SectionHeading('ຕາມພະນັກງານ'),
                        for (final s in data.salespeople)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: posCardDecoration(radius: kRadiusMd),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.nickname ??
                                              s.fullnameLo ??
                                              s.saleCode,
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${s.docCount} ບິນ',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _fmt.format(s.totalBaht),
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (data.currencies.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const _SectionHeading('ຕາມສະກຸນເງິນ'),
                        for (final c in data.currencies)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: posCardDecoration(radius: kRadiusMd),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _dsCurrencyLabel(c.currencyCode),
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _fmt.format(c.totalNative),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${c.docCount} ບິນ',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
}

String _dsCurrencyLabel(String code) {
  switch (code) {
    case '01':
      return 'ບາດ (THB)';
    case '02':
      return 'ກີບ (KIP)';
    case '03':
      return 'ໂດລາ (USD)';
    default:
      return code.isEmpty ? '—' : code;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 10) Item analytics — /api/reports/items
// ─────────────────────────────────────────────────────────────────────────

class ItemAnalyticsScreen extends StatefulWidget {
  const ItemAnalyticsScreen({super.key});
  @override
  State<ItemAnalyticsScreen> createState() => _ItemAnalyticsScreenState();
}

class _ItemAnalyticsScreenState extends State<ItemAnalyticsScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _qtyFmt = NumberFormat('#,###.##', 'en_US');
  final _searchCtl = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  Future<({
    List<ItemAnalyticsRow> rows,
    double grandTotal,
    double grandQty,
  })>? _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, 1);
    _to = DateTime(today.year, today.month, today.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<({
    List<ItemAnalyticsRow> rows,
    double grandTotal,
    double grandQty,
  })> _load() => AppScope.of(context).api.fetchItemAnalytics(
        from: _from,
        to: _to,
        q: _searchCtl.text.trim(),
      );

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ສິນຄ້າຂາຍດີ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _DateRangeBar(
              from: _from,
              to: _to,
              onChanged: (f, t) {
                _from = f;
                _to = t;
                _refresh();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtl,
              onSubmitted: (_) => _refresh(),
              decoration: InputDecoration(
                hintText: 'ຄົ້ນຫາສິນຄ້າ ຫຼື ຍີ່ຫໍ້',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtl.clear();
                          _refresh();
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonListPlaceholder();
                }
                if (snap.hasError) return _StateView.error(snap.error.toString());
                final data = snap.data!;
                if (data.rows.isEmpty) return const _StateView.empty();
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      GradientHero(
                        child: Row(
                          children: [
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ຍອດລວມ',
                                value: '${_fmt.format(data.grandTotal)} ກີບ',
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 36,
                                color:
                                    Colors.white.withValues(alpha: 0.3)),
                            Expanded(
                              child: _HeroStatColumn(
                                label: 'ຈຳນວນລວມ',
                                value: _qtyFmt.format(data.grandQty),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < data.rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _ItemRow(
                            rank: i + 1,
                            row: data.rows[i],
                            fmt: _fmt,
                            qtyFmt: _qtyFmt),
                      ],
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
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.rank,
    required this.row,
    required this.fmt,
    required this.qtyFmt,
  });
  final int rank;
  final ItemAnalyticsRow row;
  final NumberFormat fmt;
  final NumberFormat qtyFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: posCardDecoration(radius: kRadiusMd),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardElev,
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.itemName ?? row.itemCode,
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
                  '${row.itemCode}${row.brandName != null ? " · ${row.brandName}" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${qtyFmt.format(row.totalQty)} ${row.unitName ?? ''} · ${row.orderCount} ບິນ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt.format(row.totalAmount),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                'ກີບ',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 11) Daily payment settlement — /api/reports/daily-payments
// ─────────────────────────────────────────────────────────────────────────

class DailyPaymentsScreen extends StatefulWidget {
  const DailyPaymentsScreen({super.key});
  @override
  State<DailyPaymentsScreen> createState() => _DailyPaymentsScreenState();
}

class _DailyPaymentsScreenState extends State<DailyPaymentsScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  late DateTime _date;
  Future<({
    String date,
    DailyPaymentTotals totals,
    Map<String, double> breakdown,
    List<DailyPaymentRow> rows,
  })>? _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _date = DateTime(today.year, today.month, today.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<({
    String date,
    DailyPaymentTotals totals,
    Map<String, double> breakdown,
    List<DailyPaymentRow> rows,
  })> _load() => AppScope.of(context).api.fetchDailyPayments(date: _date);

  void _refresh() => setState(() => _future = _load());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      _date = picked;
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ຍອດຮັບເງິນລາຍວັນ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardElev,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_date),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonListPlaceholder();
                }
                if (snap.hasError) return _StateView.error(snap.error.toString());
                final data = snap.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      GradientHero(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeroStatColumn(
                              label: 'ຍອດຮັບເງິນລວມ (ກີບ)',
                              value: _fmt.format(data.totals.kipActive),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${data.totals.receiptsActive} ໃບຮັບເງິນ${data.totals.receiptsCancelled > 0 ? " · ${data.totals.receiptsCancelled} ຍົກເລີກ" : ""}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: posCardDecoration(radius: kRadiusMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ແບ່ງຕາມສະກຸນເງິນ × ວິທີຊຳລະ',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _breakdownRow(
                                'ກີບ · ເງິນສົດ',
                                AppColors.success,
                                data.breakdown['02:cash'] ?? 0),
                            _breakdownRow(
                                'ກີບ · ໂອນ',
                                AppColors.info,
                                data.breakdown['02:transfer'] ?? 0),
                            _breakdownRow(
                                'ບາດ · ເງິນສົດ',
                                AppColors.success,
                                data.breakdown['01:cash'] ?? 0),
                            _breakdownRow(
                                'ບາດ · ໂອນ',
                                AppColors.info,
                                data.breakdown['01:transfer'] ?? 0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (data.rows.isNotEmpty) ...[
                        const _SectionHeading('ໃບຮັບເງິນທັງໝົດ'),
                        for (final r in data.rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: posCardDecoration(radius: kRadiusMd),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r.custName ?? r.custCode ?? '—',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (r.isCancelled)
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.danger
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          kRadiusXl),
                                                ),
                                                child: Text(
                                                  'ຍົກເລີກ',
                                                  style: TextStyle(
                                                    color: AppColors.danger,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${r.docNo} · ${r.docTime ?? ''}',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _fmt.format(r.totalAmountKip),
                                    style: TextStyle(
                                      color: r.isCancelled
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      decoration: r.isCancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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

  Widget _breakdownRow(String label, Color dot, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _fmt.format(value),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
