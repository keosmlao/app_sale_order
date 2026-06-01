import 'dart:async';

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
  final _moneyFmt = NumberFormat('#,###.##', 'en_US');
  final _dateFmt = DateFormat('dd/MM HH:mm');
  final _fullDateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final _searchCtl = TextEditingController();

  Future<List<SaleOrder>>? _future;
  Timer? _searchDebounce;
  String _filter = 'PENDING';
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.listOrders();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = AppScope.of(context).api.listOrders();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the error state; RefreshIndicator only needs
      // the refresh gesture to complete cleanly.
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchCtl.clear();
    setState(() {
      _filter = 'PENDING';
      _query = '';
    });
  }

  // Workflow colours — amber for waiting, emerald for paid, blue for
  // scheduled (in a delivery trip, derived from wms_trans_detail), red for
  // cancelled.
  Color _statusColor(String s) {
    switch (s) {
      case 'PAID':
      case 'COMPLETED':
        return AppColors.success;
      case 'SCHEDULED':
      case 'SHIPPED':
        return AppColors.info;
      case 'CANCELLED':
        return AppColors.danger;
      case 'PENDING':
      default:
        return AppColors.warning;
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
    if (mounted) await _reload();
  }

  List<SaleOrder> _filtered(List<SaleOrder> all) {
    final q = _query.trim().toLowerCase();
    final filtered = <SaleOrder>[];
    for (final o in all) {
      if (o.status != _filter) continue;
      if (q.isEmpty) {
        filtered.add(o);
        continue;
      }
      final customerName = o.customer?.name.toLowerCase() ?? '';
      final docNo = o.docNo?.toLowerCase() ?? '';
      if (customerName.contains(q) ||
          o.id.toLowerCase().contains(q) ||
          docNo.contains(q)) {
        filtered.add(o);
      }
    }
    return filtered;
  }

  Map<String, int> _countByStatus(List<SaleOrder> orders) {
    final m = <String, int>{'PENDING': 0, 'COMPLETED': 0};
    for (final o in orders) {
      if (o.status == 'PENDING' || o.status == 'COMPLETED') {
        m[o.status] = (m[o.status] ?? 0) + 1;
      }
    }
    return m;
  }

  double _sumByStatus(List<SaleOrder> orders, String status) {
    var sum = 0.0;
    for (final o in orders) {
      if (o.status == status) sum += o.total;
    }
    return sum;
  }

  void _showDetail(SaleOrder o) {
    // Detail is now a full page — easier to read on a phone and lets the
    // user use the system back gesture instead of a tiny grab handle.
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => _OrderDetailScreen(
              order: o,
              fmt: _moneyFmt,
              dateFmt: _fullDateFmt,
              statusColor: _statusColor(o.status),
              statusLabel: _statusLabel(o.status),
            ),
          ),
        )
        .then((changed) {
          if (changed == true && mounted) _reload();
        });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        floatingActionButton: Material(
          color: AppColors.primary,
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: InkWell(
            onTap: _openCreate,
            borderRadius: BorderRadius.circular(kRadiusPill),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 5),
                  Text(
                    'ສ້າງບິນ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabletConstrain(
          maxWidth: 900,
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.cardBg,
            onRefresh: _reload,
            child: FutureBuilder<List<SaleOrder>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const BrandedSpinner(label: 'ກຳລັງໂຫຼດ Order…');
                }
                if (snap.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(kSpace5),
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
                final scoped = orders;
                final filtered = _filtered(orders);
                final statusCounts = _countByStatus(scoped);
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _OrdersHeader(
                        filter: _filter,
                        totalCount: orders.length,
                        pendingCount: statusCounts['PENDING'] ?? 0,
                        completedCount: statusCounts['COMPLETED'] ?? 0,
                        pendingTotal: _sumByStatus(scoped, 'PENDING'),
                        completedTotal: _sumByStatus(scoped, 'COMPLETED'),
                        moneyFmt: _moneyFmt,
                        searchController: _searchCtl,
                        onSearchChanged: _onSearchChanged,
                        onFilterChanged: (f) => setState(() => _filter = f),
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
                        child: _NoMatchView(onClear: _clearFilters),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          kSpace4,
                          kSpace2,
                          kSpace4,
                          96,
                        ),
                        sliver: SliverList.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final order = filtered[i];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i == filtered.length - 1 ? 0 : kSpace3,
                              ),
                              child: _OrderRow(
                                order: order,
                                fmt: _moneyFmt,
                                dateFmt: _dateFmt,
                                statusColor: _statusColor(order.status),
                                statusLabel: _statusLabel(order.status),
                                onTap: () => _showDetail(order),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Purple gradient header (matches the inventory screen): icon + title +
// subtitle, two tappable status stat-tiles that act as the filter, and the
// search field — all inside one card.
class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.filter,
    required this.totalCount,
    required this.pendingCount,
    required this.completedCount,
    required this.pendingTotal,
    required this.completedTotal,
    required this.moneyFmt,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final String filter;
  final int totalCount;
  final int pendingCount;
  final int completedCount;
  final double pendingTotal;
  final double completedTotal;
  final NumberFormat moneyFmt;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace2),
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sale Orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ລາຍການຂາຍ ແລະ ສະຖານະຮັບເງິນ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$totalCount ບິນ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace4),
          Row(
            children: [
              Expanded(
                child: _OrderFilterTile(
                  label: 'ລໍຖ້າຮັບເງິນ',
                  count: pendingCount,
                  total: pendingTotal,
                  color: AppColors.warning,
                  selected: filter == 'PENDING',
                  moneyFmt: moneyFmt,
                  onTap: () => onFilterChanged('PENDING'),
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                child: _OrderFilterTile(
                  label: 'ຮັບເງິນສຳເລັດ',
                  count: completedCount,
                  total: completedTotal,
                  color: AppColors.success,
                  selected: filter == 'COMPLETED',
                  moneyFmt: moneyFmt,
                  onTap: () => onFilterChanged('COMPLETED'),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: SearchField(
              controller: searchController,
              hint: 'ຄົ້ນຫາລູກຄ້າ ຫຼື ເລກ Order…',
              onChanged: onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// Tappable status stat-tile on the purple header. Selected → solid white
// card (status-coloured figures); unselected → translucent white-on-purple.
class _OrderFilterTile extends StatelessWidget {
  const _OrderFilterTile({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.selected,
    required this.moneyFmt,
    required this.onTap,
  });

  final String label;
  final int count;
  final double total;
  final Color color;
  final bool selected;
  final NumberFormat moneyFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: AnimatedContainer(
          duration: kMotionFast,
          padding: const EdgeInsets.fromLTRB(kSpace3, 9, kSpace3, 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.textSecondary
                            : Colors.white.withValues(alpha: 0.78),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? color : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      moneyFmt.format(total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? AppColors.textPrimary : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -0.3,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'ກີບ',
                    style: TextStyle(
                      color: selected
                          ? AppColors.textMuted
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

// Order card styled like the product tiles (_ProductTile) in the order
// picker: bordered card, left status-colour accent bar, name + status pill,
// doc/amount row, salesperson + date row.
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

  @override
  Widget build(BuildContext context) {
    final docLabel = order.docNo?.trim().isNotEmpty == true
        ? order.docNo!
        : '#${order.id.toUpperCase()}';
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.customer?.name ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              docLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmt.format(order.total),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -0.2,
                              fontFeatures: kTabularFigures,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'ກີບ',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (order.salesperson != null) ...[
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                order.salesperson!.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Spacer(),
                          Icon(
                            Icons.event_outlined,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            dateFmt.format(order.createdAt.toLocal()),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFeatures: kTabularFigures,
                            ),
                          ),
                        ],
                      ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Borderless soft-tint pill. The colour comes through as background fill
    // and as text — no border ring, no uppercase tracking.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ThemeService.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailScreen extends StatefulWidget {
  const _OrderDetailScreen({
    required this.order,
    required this.fmt,
    required this.dateFmt,
    required this.statusColor,
    required this.statusLabel,
  });
  final SaleOrder order;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color statusColor;
  final String statusLabel;

  @override
  State<_OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<_OrderDetailScreen> {
  bool _busy = false;

  double get _lineSubtotal {
    var sum = 0.0;
    for (final item in widget.order.items) {
      sum += item.subtotal;
    }
    return sum;
  }

  double get _memberDiscountAmount {
    final pct = widget.order.customer?.discountPct ?? 0;
    if (pct <= 0) return 0;
    return _lineSubtotal * (pct / 100);
  }

  String _pctLabel(double pct) =>
      pct == pct.toInt() ? pct.toInt().toString() : pct.toStringAsFixed(1);

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

  // Hard-delete (web parity) — removes the order entirely instead of
  // setting status=CANCELLED. Only available on PENDING orders that have
  // not been settled at the cashier.
  Future<void> _doDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ລົບ Order'),
        content: Text(
          'ຕ້ອງການລົບ Order #${widget.order.id} ຖາວອນ?\n'
          'ຂໍ້ມູນຈະບໍ່ສາມາດກູ້ຄືນໄດ້.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ບໍ່'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('ລົບຖາວອນ'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.deleteOrder(widget.order.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ລົບ Order ສຳເລັດ ✓'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(12),
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
    final customer = order.customer;
    final discountPct = customer?.discountPct ?? 0;
    final memberDiscount = _memberDiscountAmount;
    final extraDiscount = order.extraDiscount;
    final pointBalance = customer?.pointBalance ?? 0;
    final hasBenefits =
        discountPct > 0 ||
        memberDiscount > 0 ||
        extraDiscount > 0 ||
        pointBalance > 0;
    final docLabel = order.docNo?.trim().isNotEmpty == true
        ? order.docNo!
        : '#${order.id.toUpperCase()}';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: premiumAppBar(context, docLabel),
      body: TabletConstrain(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
            if (hasBenefits) ...[
              _sectionLabel('ສ່ວນຫຼຸດ / ແຕ້ມສະສົມ'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (discountPct > 0)
                      _kvRow('ສ່ວນຫຼຸດສະມາຊິກ', '${_pctLabel(discountPct)}%'),
                    if (memberDiscount > 0)
                      _kvRow(
                        'ມູນຄ່າສ່ວນຫຼຸດ',
                        '−${fmt.format(memberDiscount)} ກີບ',
                      ),
                    if (extraDiscount > 0)
                      _kvRow(
                        'ສ່ວນຫຼຸດທ້າຍບິນ',
                        '−${fmt.format(extraDiscount)} ກີບ',
                      ),
                    if (pointBalance > 0)
                      _kvRow('ແຕ້ມສະສົມ', '${fmt.format(pointBalance)} ແຕ້ມ'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (order.settlement != null) ...[
              _sectionLabel('ການຮັບເງິນ'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kvRow(
                      'ໃບຮັບເງິນ',
                      order.settlement!.receiptNo,
                      mono: true,
                    ),
                    if (order.settlement!.settledAt != null)
                      _kvRow(
                        'ວັນ-ເວລາ',
                        dateFmt.format(order.settlement!.settledAt!.toLocal()),
                      ),
                    _kvRow('ຜູ້ຮັບເງິນ', order.settlement!.cashierName ?? '—'),
                    _kvRow(
                      'ປະເພດການຮັບເງິນ',
                      order.settlement!.paymentTypeLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            // ================= REDESIGNED ITEMS SECTION =================
            _sectionLabel('ITEMS'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: order.items.length,
                separatorBuilder: (_, __) => Divider(height: 0, thickness: 1, color: AppColors.divider),
                itemBuilder: (context, i) {
                  final item = order.items[i];
                  final product = item.product;
                  final hasImage = product?.imageUrl != null && product!.imageUrl!.trim().isNotEmpty;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ----- Product image (or placeholder) -----
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: hasImage
                                ? Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _itemPlaceholder(),
                                  )
                                : _itemPlaceholder(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ----- Product details -----
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      product?.name ?? item.productId,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Quantity badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'x${item.quantity}',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (product?.id != null && product!.id.isNotEmpty)
                                Text(
                                  product.id,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              const SizedBox(height: 6),
                              // Price & quantity line (unit price × quantity)
                              Row(
                                children: [
                                  Text(
                                    fmt.format(item.unitPrice),
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(' × ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  Text(
                                    item.quantity.toString(),
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Subtotal (bold, gold‑accented)
                                  Text(
                                    fmt.format(item.subtotal),
                                    style: TextStyle(
                                      color: AppColors.goldBright,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            // ================= END REDESIGNED ITEMS SECTION =================
            _sectionLabel('SUMMARY'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Expanded(
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  Text(
                    fmt.format(order.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'ກີບ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
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
    final isPending = status == 'PENDING';

    return Column(
      children: [
        // PENDING orders get the edit button (opens CreateOrder pre-filled).
        if (isPending && !_busy) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CreateOrderScreen(editOrder: widget.order),
                  ),
                );
                if (changed == true && mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('ແກ້ໄຂ Order'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Primary destructive / restore action:
        //   PENDING   → ລົບ Order (hard delete via /api/cashier/orders/X)
        //   CANCELLED → ກູ້ Order ກັບຄືນ (status PATCH reopen)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy
                ? null
                : (isCancelled
                      ? () => _doAction('reopen')
                      : (isPending ? _doDelete : null)),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isCancelled ? Icons.refresh : Icons.delete_outline,
                    size: 18,
                  ),
            label: Text(
              _busy
                  ? 'ກຳລັງປະມວນຜົນ…'
                  : (isCancelled ? 'ກູ້ Order ກັບຄືນ' : 'ລົບ Order'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isCancelled ? AppColors.gold : AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kvRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
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

  // Helper for product image placeholder
  Widget _itemPlaceholder() {
    return Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 28,
        color: AppColors.textMuted.withValues(alpha: 0.5),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      icon: Icons.receipt_long_outlined,
      title: 'ຍັງບໍ່ມີ Order',
      subtitle: 'ກົດປຸ່ມ + ດ້ານລຸ່ມຂວາເພື່ອສ້າງບິນທຳອິດ',
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
              icon: Icon(Icons.clear_all, size: 17, color: AppColors.gold),
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
            child: Icon(Icons.cloud_off, size: 26, color: Color(0xFFEF4444)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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