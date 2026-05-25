import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api.dart';
import 'create_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _moneyFmt = NumberFormat('#,###.##', 'en_US');
  final _dateFmt = DateFormat('dd/MM HH:mm');
  final _fullDateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final _searchCtl = TextEditingController();

  Future<List<SaleOrder>>? _future;
  String _filter = 'ALL';
  // The backend already scopes /api/orders to the logged-in salesperson. Show
  // all returned rows by default so older orders do not look like a failed load.
  String _scope = 'ALL'; // 'TODAY' | 'ALL'
  String _query = '';

  static bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.listOrders();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.listOrders();
    });
  }

  // Workflow colours — amber for waiting, emerald for paid, blue for
  // scheduled (in a delivery trip, derived from wms_trans_detail), red for
  // cancelled.
  Color _statusColor(String s) {
    switch (s) {
      case 'PAID':
      case 'COMPLETED':
        return const Color(0xFF10B981); // emerald — paid
      case 'SCHEDULED':
      case 'SHIPPED':
        return const Color(0xFF3B82F6); // blue — assigned to a trip
      case 'CANCELLED':
        return const Color(0xFFEF4444); // red
      case 'PENDING':
      default:
        return const Color(0xFFF59E0B); // amber — waiting for cashier
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'PAID':
        return 'ຈ່າຍແລ້ວ';
      case 'COMPLETED':
        return 'ຮັບເງິນສຳເລັດ';
      case 'SCHEDULED':
      case 'SHIPPED':
        return 'ຈັດຖ້ຽວ';
      case 'CANCELLED':
        return 'ຍົກເລີກ';
      case 'PENDING':
      default:
        return 'ລໍຖ້າຮັບເງິນ';
    }
  }

  Future<void> _openCreate() async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
    if (mounted) _reload();
  }

  // Apply scope (today vs all) first, then status, then text query. Scope is
  // the top-level lens; status pills filter within the scoped subset.
  List<SaleOrder> _scoped(List<SaleOrder> all) {
    if (_scope == 'TODAY') {
      return all.where((o) => _isToday(o.createdAt)).toList();
    }
    return all;
  }

  List<SaleOrder> _filtered(List<SaleOrder> all) {
    final q = _query.trim().toLowerCase();
    return _scoped(all).where((o) {
      if (_filter != 'ALL' && o.status != _filter) return false;
      if (q.isEmpty) return true;
      return (o.customer?.name ?? '').toLowerCase().contains(q) ||
          o.id.toLowerCase().contains(q);
    }).toList();
  }

  Map<String, int> _countByStatus(List<SaleOrder> orders) {
    final m = <String, int>{
      'PENDING': 0,
      'PAID': 0,
      'SHIPPED': 0,
      'COMPLETED': 0,
      'CANCELLED': 0,
    };
    for (final o in orders) {
      m[o.status] = (m[o.status] ?? 0) + 1;
    }
    return m;
  }

  void _showDetail(SaleOrder o) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => _OrderDetailSheet(
          order: o,
          controller: controller,
          fmt: _moneyFmt,
          dateFmt: _fullDateFmt,
          statusColor: _statusColor(o.status),
          statusLabel: _statusLabel(o.status),
        ),
      ),
    ).then((changed) {
      if (changed == true && mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: TabletConstrain(
          maxWidth: 900,
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.cardBg,
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<SaleOrder>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
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
                final orders = snap.data ?? [];
                final scoped = _scoped(orders);
                final filtered = _filtered(orders);
                final totalAmt = scoped.fold<double>(0, (s, o) => s + o.total);
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeroCard(
                        scope: _scope,
                        count: scoped.length,
                        totalAmount: totalAmt,
                        fmt: _fmt,
                        moneyFmt: _moneyFmt,
                        onToggleScope: () => setState(() {
                          _scope = _scope == 'TODAY' ? 'ALL' : 'TODAY';
                        }),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _FilterBar(
                        filter: _filter,
                        statusCounts: _countByStatus(scoped),
                        totalCount: scoped.length,
                        fmt: _fmt,
                        onFilterChanged: (f) => setState(() => _filter = f),
                        statusColor: _statusColor,
                        statusLabel: _statusLabel,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _SearchField(
                          controller: _searchCtl,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ),
                    if (orders.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyOrders(),
                      )
                    else if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoMatchView(
                          onClear: () {
                            _searchCtl.clear();
                            setState(() {
                              _filter = 'ALL';
                              _query = '';
                            });
                          },
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                        sliver: SliverToBoxAdapter(
                          child: _OrdersListCard(
                            orders: filtered,
                            fmt: _moneyFmt,
                            dateFmt: _dateFmt,
                            statusColorFor: _statusColor,
                            statusLabelFor: _statusLabel,
                            onTap: _showDetail,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: TabletConstrain(
          maxWidth: 900,
          child: _CreateOrderBar(onTap: _openCreate),
        ),
      ),
    );
  }
}

class _CreateOrderBar extends StatelessWidget {
  const _CreateOrderBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Flat primary action bar — no gradient, no glow. The button itself uses
    // the theme's FilledButton style so it stays consistent with the rest of
    // the app.
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('ສ້າງ Sale Order ໃໝ່'),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.scope,
    required this.count,
    required this.totalAmount,
    required this.fmt,
    required this.moneyFmt,
    required this.onToggleScope,
  });
  final String scope;
  final int count;
  final double totalAmount;
  final NumberFormat fmt;
  final NumberFormat moneyFmt;
  final VoidCallback onToggleScope;

  @override
  Widget build(BuildContext context) {
    final isToday = scope == 'TODAY';
    final hasData = count > 0;
    // Calm white hero — the number does the work, no gradient sheen, no
    // colored borders. Scope toggle drops into a borderless ghost pill on
    // the right.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: FadeInSlide(
        duration: const Duration(milliseconds: 400),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          radius: kRadiusLg,
          child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'ມື້ນີ້' : 'ທັງໝົດ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          moneyFmt.format(totalAmount),
                          style: TextStyle(
                            color: hasData
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ກີບ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fmt.format(count)} ບິນ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Scope toggle — flips TODAY ↔ ALL. Ghost pill, no fill.
            OutlinedButton.icon(
              onPressed: onToggleScope,
              icon: Icon(
                isToday ? Icons.calendar_month_outlined : Icons.today_outlined,
                size: 16,
              ),
              label: Text(isToday ? 'ທັງໝົດ' : 'ມື້ນີ້'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusXl),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.statusCounts,
    required this.totalCount,
    required this.fmt,
    required this.onFilterChanged,
    required this.statusColor,
    required this.statusLabel,
  });

  final String filter;
  final Map<String, int> statusCounts;
  final int totalCount;
  final NumberFormat fmt;
  final ValueChanged<String> onFilterChanged;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;

  @override
  Widget build(BuildContext context) {
    // Horizontal scroll keeps the filter row to a single line so the hero +
    // search + first orders fit above the fold. The full set is one swipe away.
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          _FilterPill(
            label: 'ທັງໝົດ',
            count: totalCount,
            color: AppColors.gold,
            selected: filter == 'ALL',
            onTap: () => onFilterChanged('ALL'),
            fmt: fmt,
          ),
          const SizedBox(width: 8),
          for (final s in const [
            'PENDING',
            'PAID',
            'SHIPPED',
            'COMPLETED',
            'CANCELLED',
          ]) ...[
            _FilterPill(
              label: statusLabel(s),
              count: statusCounts[s] ?? 0,
              color: statusColor(s),
              selected: filter == s,
              onTap: () => onFilterChanged(s),
              fmt: fmt,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.fmt,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    // Borderless pill — fill swaps between cardElev (idle) and the soft
    // status tint when selected. The status-color dot is the only chrome.
    final bg = selected ? color.withValues(alpha: 0.10) : AppColors.cardElev;
    final fg = selected ? color : AppColors.textSecondary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(kRadiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? color : AppColors.textSoft,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                fmt.format(count),
                style: TextStyle(
                  color: fg.withValues(alpha: selected ? 0.85 : 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      cursorColor: AppColors.gold,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: 'ຄົ້ນຫາລູກຄ້າ ຫຼື ເລກ Order',
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.accent,
          size: 19,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 17,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: AppColors.cardBg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.6),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _OrdersListCard extends StatelessWidget {
  const _OrdersListCard({
    required this.orders,
    required this.fmt,
    required this.dateFmt,
    required this.statusColorFor,
    required this.statusLabelFor,
    required this.onTap,
  });
  final List<SaleOrder> orders;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color Function(String) statusColorFor;
  final String Function(String) statusLabelFor;
  final void Function(SaleOrder) onTap;

  @override
  Widget build(BuildContext context) {
    // Each order is its own elevated card with whitespace between rows —
    // easier to scan than a continuous striped list.
    return Column(
      children: [
        for (var i = 0; i < orders.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          FadeInSlide(
            duration: Duration(milliseconds: 300 + (i < 6 ? i * 80 : 480)),
            delay: Duration(milliseconds: i < 6 ? i * 50 : 300),
            child: _OrderRow(
              order: orders[i],
              fmt: fmt,
              dateFmt: dateFmt,
              statusColor: statusColorFor(orders[i].status),
              statusLabel: statusLabelFor(orders[i].status),
              onTap: () => onTap(orders[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.fmt,
    required this.dateFmt,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
  });

  final SaleOrder order;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;

  // First non-empty rune of the customer name → seeds the avatar bubble.
  String _avatarInitial() {
    final name = order.customer?.name.trim() ?? '';
    if (name.isEmpty) return '#';
    final ch = name.runes.first;
    return String.fromCharCode(ch).toUpperCase();
  }

  IconData _statusIcon() {
    switch (order.status.toUpperCase()) {
      case 'COMPLETED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'PENDING':
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final docLabel = order.docNo?.trim().isNotEmpty == true
        ? order.docNo!
        : '#${order.id.toUpperCase()}';
    // Card body is flat white with the global soft shadow (posCardDecoration).
    // No border. Tap area covers the whole card via InkWell.
    return GlassCard(
      radius: kRadiusMd,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Header row: neutral monogram avatar + customer + status pill.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                        _avatarInitial(),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customer?.name ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            docLabel,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      color: statusColor,
                      label: statusLabel,
                      icon: _statusIcon(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                // Footer: meta on the left, total on the right. Total is the
                // dominant text here so it stays w700 — everything else is
                // muted secondary.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _MetaChip(
                            icon: Icons.event_outlined,
                            label: dateFmt.format(order.createdAt.toLocal()),
                          ),
                          _MetaChip(
                            icon: Icons.shopping_bag_outlined,
                            label: '${order.items.length} ລາຍການ',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmt.format(order.total),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            'ກີບ',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

// Small icon + label chip used in the footer of the redesigned order row.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.color, required this.label, this.icon});
  final Color color;
  final String label;
  // Optional leading icon — when null we fall back to the original colored
  // dot so existing callers keep their look.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Borderless soft-tint pill. The colour comes through as background fill
    // and as text — no border ring, no uppercase tracking.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 12, color: color),
            )
          else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({
    required this.order,
    required this.controller,
    required this.fmt,
    required this.dateFmt,
    required this.statusColor,
    required this.statusLabel,
  });
  final SaleOrder order;
  final ScrollController controller;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color statusColor;
  final String statusLabel;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _busy = false;

  Future<void> _doAction(String action) async {
    final isCancel = action == 'cancel';
    final reasonCtl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCancel ? 'ຍົກເລີກ Order' : 'ກູ້ຄືນ Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCancel
                  ? 'ຕ້ອງການຍົກເລີກ Order #${widget.order.id} ແທ້ບໍ?\nກະລຸນາໃສ່ເຫດຜົນເພື່ອບັນທຶກ.'
                  : 'ຕ້ອງການກູ້ Order #${widget.order.id} ກັບໄປເປັນ PENDING ບໍ?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtl,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isCancel ? 'ເຫດຜົນ *' : 'ເຫດຜົນ (optional)',
                hintText: isCancel
                    ? 'ເຊັ່ນ: ລູກຄ້າຍົກເລີກ, ສິນຄ້າບໍ່ມີ...'
                    : 'ເຊັ່ນ: ຍົກເລີກພາດ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ບໍ່'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isCancel ? AppColors.danger : AppColors.gold,
              foregroundColor: Colors.white,
            ),
            child: Text(isCancel ? 'ຍົກເລີກ' : 'ກູ້ຄືນ'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final reason = reasonCtl.text.trim();
    if (isCancel && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ກະລຸນາໃສ່ເຫດຜົນຍົກເລີກ'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(12),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.updateOrderStatus(
        orderId: widget.order.id,
        action: action,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCancel ? 'ຍົກເລີກ Order ສຳເລັດ ✓' : 'ກູ້ຄືນ Order ສຳເລັດ ✓',
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ຜິດພາດ: ${e.message}'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ຜິດພາດ: $e'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final fmt = widget.fmt;
    final dateFmt = widget.dateFmt;
    final statusColor = widget.statusColor;
    final statusLabel = widget.statusLabel;
    final controller = widget.controller;
    final docLabel = order.docNo?.trim().isNotEmpty == true
        ? order.docNo!
        : '#${order.id.toUpperCase()}';
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _sectionLabel('ORDER DETAIL'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customer?.name ?? '—',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                        ),
                        _StatusBadge(color: statusColor, label: statusLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          docLabel,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '   ·   ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          dateFmt.format(order.createdAt.toLocal()),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (order.customer?.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        order.customer!.phone!,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (order.salesperson != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 14,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ພະນັກງານຂາຍ: ${order.salesperson!.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionLabel('ITEMS'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: List.generate(order.items.length, (i) {
                    final it = order.items[i];
                    final isLast = i == order.items.length - 1;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isLast
                                ? Colors.transparent
                                : AppColors.divider,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.product?.name ?? it.productId,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${fmt.format(it.unitPrice)} × ${it.quantity}',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmt.format(it.subtotal),
                            style: TextStyle(
                              color: AppColors.goldBright,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              _sectionLabel('SUMMARY'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.cardElev,
                      AppColors.gold.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        'TOTAL',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    Text(
                      fmt.format(order.total),
                      style: TextStyle(
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'ກີບ',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildActions(order.status),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(String status) {
    // Backend only flips PENDING ↔ CANCELLED from mobile. COMPLETED is set by
    // the cashier settlement flow and is read-only here.
    if (status == 'COMPLETED') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.success, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Order ນີ້ຮັບເງິນແລ້ວ — ປ່ຽນສະຖານະບໍ່ໄດ້',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Cancel/reopen is restricted to head/manager (server-side too). Lower
    // roles see a hint banner explaining the limit so they don't think the
    // button is missing/broken.
    final me = AppScope.of(context).auth.employee;
    if (me == null || !me.canCancelOrders) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ສະເພາະຫົວໜ້າ ຫຼື ຜູ້ຈັດການ ປ່ຽນສະຖານະ Order ໄດ້',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final isCancelled = status == 'CANCELLED';
    final actionLabel = isCancelled ? 'ກູ້ Order ກັບຄືນ' : 'ຍົກເລີກ Order';
    final actionColor = isCancelled ? AppColors.gold : AppColors.danger;
    final actionIcon = isCancelled ? Icons.refresh : Icons.cancel_outlined;
    final actionKey = isCancelled ? 'reopen' : 'cancel';
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _busy ? null : () => _doAction(actionKey),
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(actionIcon, size: 18),
        label: Text(_busy ? 'ກຳລັງປະມວນຜົນ…' : actionLabel),
        style: FilledButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          t,
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.18),
                    AppColors.gold.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_shopping_cart,
                color: AppColors.gold,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ຍັງບໍ່ມີ Order',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ກົດປຸ່ມ "ສ້າງ Order" ດ້ານລຸ່ມ\nເພື່ອເລີ່ມຂາຍບິນທຳອິດ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              Icons.arrow_downward_rounded,
              color: AppColors.gold,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchView extends StatelessWidget {
  const _NoMatchView({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              color: AppColors.textMuted,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'No matching orders',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: Icon(
                Icons.clear_all,
                size: 17,
                color: AppColors.gold,
              ),
              label: Text(
                'Clear filters',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off,
              size: 26,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, size: 17, color: AppColors.bg),
            label: Text(
              'Try again',
              style: TextStyle(
                color: AppColors.bg,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}