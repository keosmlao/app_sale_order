import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/inventory_cache.dart';
import 'inventory_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum _StockFilter { all, inStock, lowStock, outOfStock }

class _InventoryScreenState extends State<InventoryScreen> {
  static const int _initialVisibleCount = 30;
  static const int _loadMoreCount = 30;

  final _fmt = NumberFormat('#,###', 'en_US');
  final _qtyFmt = NumberFormat('#,###.##', 'en_US');
  final _dateFmt = DateFormat('HH:mm');
  final _cache = InventoryCache();
  final _scrollController = ScrollController();
  final _searchCtl = TextEditingController();

  List<InventoryItem> _items = const [];
  List<String> _salesWarehouses = const [];
  DateTime? _syncedAt;
  bool _loading = false;
  bool _syncing = false;
  String? _error;
  String _query = '';
  _StockFilter _stockFilter = _StockFilter.all;
  InventoryScope _scope = InventoryScope.company;
  bool _booted = false;
  int _visibleCount = _initialVisibleCount;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_booted) {
      _booted = true;
      _boot();
    }
  }

  Future<void> _boot() async {
    setState(() => _loading = true);
    final snap = await _cache.read();
    if (mounted && snap != null && !snap.isEmpty) {
      setState(() {
        _items = snap.items;
        _salesWarehouses = snap.salesWarehouses;
        _syncedAt = snap.syncedAt;
        _loading = false;
        _visibleCount = _initialVisibleCount;
      });
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sync({bool showMessage = false}) async {
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final results = await Future.wait([
        api.fetchInventory(),
        api.fetchSalesBalances(),
        api.fetchCompanyBalances(),
      ]);
      final inv =
          results[0]
              as ({
                DateTime syncedAt,
                List<InventoryItem> items,
                List<String> salesWarehouses,
              });
      final sales =
          results[1]
              as ({
                Map<String, double> balanceByCode,
                Map<String, double> minimumByCode,
                List<String> warehouses,
              });
      final company = results[2] as Map<String, double>;
      final merged = inv.items
          .map(
            (p) => p.copyWith(
              resetCompanyBalance: true,
              companyBalance: company[p.code] ?? 0,
              salesBalance: sales.balanceByCode[p.code] ?? 0,
              salesMinimumStock:
                  sales.minimumByCode[p.code] ?? p.salesMinimumStock,
            ),
          )
          .toList();
      await _cache.write(
        InventorySnapshot(
          syncedAt: inv.syncedAt,
          items: merged,
          salesWarehouses: inv.salesWarehouses,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items = merged;
        _salesWarehouses = inv.salesWarehouses;
        _syncedAt = inv.syncedAt;
        _visibleCount = _initialVisibleCount;
      });
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ດຶງ stock ແລະບັນທຶກໃນເຄື່ອງແລ້ວ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ດຶງ stock ບໍ່ສຳເລັດ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _loading = false;
        });
      }
    }
  }

  List<InventoryItem> get _scopedItems {
    if (_scope == InventoryScope.sales) {
      return _items.where((p) => p.balanceFor(_scope) > 0).toList();
    }
    return _items;
  }

  _StockStats get _stats {
    int inStock = 0, lowStock = 0, outOfStock = 0;
    for (final p in _scopedItems) {
      final b = p.balanceFor(_scope);
      if (b <= 0) {
        outOfStock++;
      } else if (_isLowStock(p, b)) {
        lowStock++;
      } else {
        inStock++;
      }
    }
    return _StockStats(
      total: _scopedItems.length,
      inStock: inStock,
      lowStock: lowStock,
      outOfStock: outOfStock,
    );
  }

  List<InventoryItem> get _filtered {
    final q = _query.trim().toLowerCase();
    return _scopedItems.where((p) {
      final bal = p.balanceFor(_scope);
      switch (_stockFilter) {
        case _StockFilter.all:
          break;
        case _StockFilter.inStock:
          if (bal <= 0 || _isLowStock(p, bal)) return false;
          break;
        case _StockFilter.lowStock:
          if (bal <= 0 || !_isLowStock(p, bal)) return false;
          break;
        case _StockFilter.outOfStock:
          if (bal > 0) return false;
          break;
      }
      if (q.isEmpty) return true;
      return p.nameLo.toLowerCase().contains(q) ||
          p.code.toLowerCase().contains(q) ||
          (p.nameEng ?? '').toLowerCase().contains(q) ||
          (p.brand ?? '').toLowerCase().contains(q) ||
          (p.brandName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _resetVisibleCount() {
    _visibleCount = _initialVisibleCount;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _loadMore() {
    if (_loading) return;
    final total = _filtered.length;
    if (_visibleCount >= total) return;
    setState(() {
      final next = _visibleCount + _loadMoreCount;
      _visibleCount = next > total ? total : next;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 260) _loadMore();
    return false;
  }

  Color _stockColor(double b) {
    if (b <= 0) return AppColors.danger;
    return AppColors.success;
  }

  bool _isLowStock(InventoryItem item, double balance) {
    final min = item.salesMinimumStock;
    if (min > 0) return balance < min;
    return balance <= 5;
  }

  Color _stockColorForItem(InventoryItem item, double b) {
    if (b <= 0) return AppColors.danger;
    if (_isLowStock(item, b)) return AppColors.warning;
    return AppColors.success;
  }

  String _stockLabelForItem(InventoryItem item, double b) {
    if (b <= 0) return 'Out';
    if (_isLowStock(item, b)) return 'Low';
    return 'In stock';
  }

  String _qtyText(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return _qtyFmt.format(v);
  }

  void _openDetail(InventoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(
          item: item,
          scope: _scope,
          salesWarehouses: _salesWarehouses,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.cardBg,
        onRefresh: _sync,
        child: TabletConstrain(maxWidth: 900, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          _ErrorCard(message: _error!, onRetry: _sync),
        ],
      );
    }

    final list = _filtered;
    final visibleCount = _visibleCount > list.length
        ? list.length
        : _visibleCount;
    final visibleList = list.take(visibleCount).toList();
    final hasMore = visibleCount < list.length;
    final stats = _stats;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _HeroCard(
              scope: _scope,
              stats: stats,
              syncedAt: _syncedAt,
              syncing: _syncing,
              dateFmt: _dateFmt,
              fmt: _fmt,
              onSync: _syncing ? null : () => _sync(showMessage: true),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ScopePicker(
                scope: _scope,
                salesWarehouses: _salesWarehouses,
                onChanged: (s) => setState(() {
                  _scope = s;
                  _stockFilter = _StockFilter.all;
                  _resetVisibleCount();
                }),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterBar(
              stockFilter: _stockFilter,
              stats: stats,
              fmt: _fmt,
              onFilterChanged: (f) => setState(() {
                _stockFilter = f;
                _resetVisibleCount();
              }),
              stockColorFor: _stockColor,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _SearchField(
                controller: _searchCtl,
                onChanged: (v) => setState(() {
                  _query = v;
                  _resetVisibleCount();
                }),
              ),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyView(
                hasQuery: _query.isNotEmpty,
                onClear: () {
                  _searchCtl.clear();
                  setState(() {
                    _query = '';
                    _stockFilter = _StockFilter.all;
                    _resetVisibleCount();
                  });
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              sliver: SliverToBoxAdapter(
                child: _InventoryListCard(
                  items: visibleList,
                  scope: _scope,
                  fmt: _qtyFmt,
                  stockColorFor: _stockColorForItem,
                  stockLabelFor: _stockLabelForItem,
                  qtyTextFor: _qtyText,
                  hasMore: hasMore,
                  remaining: list.length - visibleCount,
                  onLoadMore: _loadMore,
                  remainingFmt: _fmt,
                  onTap: _openDetail,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockStats {
  const _StockStats({
    required this.total,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });
  final int total;
  final int inStock;
  final int lowStock;
  final int outOfStock;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.scope,
    required this.stats,
    required this.syncedAt,
    required this.syncing,
    required this.dateFmt,
    required this.fmt,
    required this.onSync,
  });

  final InventoryScope scope;
  final _StockStats stats;
  final DateTime? syncedAt;
  final bool syncing;
  final DateFormat dateFmt;
  final NumberFormat fmt;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final isCompany = scope == InventoryScope.company;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: FadeInSlide(
        duration: const Duration(milliseconds: 400),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          radius: kRadiusLg,
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
                        isCompany ? 'ສິນຄ້າທັງບໍລິສັດ' : 'ສິນຄ້າຄັງຂາຍ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            fmt.format(stats.total),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SKU',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _SyncChip(
                  syncedAt: syncedAt,
                  syncing: syncing,
                  dateFmt: dateFmt,
                  onSync: onSync,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),
            // Three mini-stats — soft tints (emerald / amber / red).
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'ມີສິນຄ້າ',
                    value: stats.inStock,
                    color: AppColors.success,
                    fmt: fmt,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'ໃກ້ໝົດ',
                    value: stats.lowStock,
                    color: AppColors.warning,
                    fmt: fmt,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'ໝົດ',
                    value: stats.outOfStock,
                    color: AppColors.danger,
                    fmt: fmt,
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.fmt,
  });
  final String label;
  final int value;
  final Color color;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(value),
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({
    required this.syncedAt,
    required this.syncing,
    required this.dateFmt,
    required this.onSync,
  });
  final DateTime? syncedAt;
  final bool syncing;
  final DateFormat dateFmt;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onSync,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              syncing
                  ? SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    )
                  : Icon(
                      Icons.cloud_sync_outlined,
                      size: 14,
                      color: AppColors.gold,
                    ),
              if (syncedAt != null) ...[
                const SizedBox(width: 5),
                Text(
                  dateFmt.format(syncedAt!.toLocal()),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopePicker extends StatelessWidget {
  const _ScopePicker({
    required this.scope,
    required this.salesWarehouses,
    required this.onChanged,
  });
  final InventoryScope scope;
  final List<String> salesWarehouses;
  final ValueChanged<InventoryScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _opt(
              active: scope == InventoryScope.company,
              icon: Icons.business_outlined,
              label: 'ບໍລິສັດ',
              onTap: () => onChanged(InventoryScope.company),
            ),
          ),
          Expanded(
            child: _opt(
              active: scope == InventoryScope.sales,
              icon: Icons.storefront_outlined,
              label: salesWarehouses.isEmpty
                  ? 'ຂາຍ'
                  : 'ຂາຍ · ${salesWarehouses.join("/")}',
              onTap: () => onChanged(InventoryScope.sales),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opt({
    required bool active,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.goldBright, AppColors.gold],
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.bg : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.bg : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
    required this.stockFilter,
    required this.stats,
    required this.fmt,
    required this.onFilterChanged,
    required this.stockColorFor,
  });

  final _StockFilter stockFilter;
  final _StockStats stats;
  final NumberFormat fmt;
  final ValueChanged<_StockFilter> onFilterChanged;
  final Color Function(double) stockColorFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FilterPill(
            label: 'All',
            count: stats.total,
            color: AppColors.gold,
            selected: stockFilter == _StockFilter.all,
            onTap: () => onFilterChanged(_StockFilter.all),
            fmt: fmt,
          ),
          _FilterPill(
            label: 'In stock',
            count: stats.inStock,
            color: AppColors.success,
            selected: stockFilter == _StockFilter.inStock,
            onTap: () => onFilterChanged(_StockFilter.inStock),
            fmt: fmt,
          ),
          _FilterPill(
            label: 'Low',
            count: stats.lowStock,
            color: AppColors.warning,
            selected: stockFilter == _StockFilter.lowStock,
            onTap: () => onFilterChanged(_StockFilter.lowStock),
            fmt: fmt,
          ),
          _FilterPill(
            label: 'Out',
            count: stats.outOfStock,
            color: AppColors.danger,
            selected: stockFilter == _StockFilter.outOfStock,
            onTap: () => onFilterChanged(_StockFilter.outOfStock),
            fmt: fmt,
          ),
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
    final bg = selected ? color.withValues(alpha: 0.15) : AppColors.cardBg;
    final fg = selected ? color : AppColors.textSecondary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? color : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.18)
                      : AppColors.bg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fmt.format(count),
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
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
        hintText: 'ຄົ້ນຫາ ຊື່ / ລະຫັດ / ຍີ່ຫໍ້',
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(
          Icons.search,
          color: AppColors.textSecondary,
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

class _InventoryListCard extends StatelessWidget {
  const _InventoryListCard({
    required this.items,
    required this.scope,
    required this.fmt,
    required this.stockColorFor,
    required this.stockLabelFor,
    required this.qtyTextFor,
    required this.hasMore,
    required this.remaining,
    required this.onLoadMore,
    required this.remainingFmt,
    required this.onTap,
  });

  final List<InventoryItem> items;
  final InventoryScope scope;
  final NumberFormat fmt;
  final Color Function(InventoryItem, double) stockColorFor;
  final String Function(InventoryItem, double) stockLabelFor;
  final String Function(double) qtyTextFor;
  final bool hasMore;
  final int remaining;
  final VoidCallback onLoadMore;
  final NumberFormat remainingFmt;
  final void Function(InventoryItem) onTap;

  @override
  Widget build(BuildContext context) {
    return FadeInSlide(
      duration: const Duration(milliseconds: 500),
      child: GlassCard(
        radius: kRadiusLg,
        padding: EdgeInsets.zero,
        child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            _InventoryRow(
              item: items[i],
              bal: items[i].balanceFor(scope),
              fmt: fmt,
              stockColor: stockColorFor(items[i], items[i].balanceFor(scope)),
              stockLabel: stockLabelFor(items[i], items[i].balanceFor(scope)),
              qtyText: qtyTextFor(items[i].balanceFor(scope)),
              showDivider: i != items.length - 1 || hasMore,
              onTap: () => onTap(items[i]),
            ),
          if (hasMore)
            InkWell(
              onTap: onLoadMore,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.expand_more,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ໂຫຼດເພີ່ມ · ເຫຼືອ ${remainingFmt.format(remaining)}',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.item,
    required this.bal,
    required this.fmt,
    required this.stockColor,
    required this.stockLabel,
    required this.qtyText,
    required this.showDivider,
    required this.onTap,
  });

  final InventoryItem item;
  final double bal;
  final NumberFormat fmt;
  final Color stockColor;
  final String stockLabel;
  final String qtyText;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = item.brandName ?? item.brand;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.gold.withValues(alpha: 0.08),
        highlightColor: AppColors.gold.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: showDivider ? AppColors.divider : Colors.transparent,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Glowing stock accent bar.
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: stockColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: stockColor.withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.nameLo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(color: stockColor, label: stockLabel),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.code,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (brand != null && brand.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.business_outlined,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        qtyText,
                        style: TextStyle(
                          color: stockColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if ((item.unitName ?? '').isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Text(
                          item.unitName!,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.salePriceKip > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${fmt.format(item.salePriceKip)} ກີບ',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 18,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasQuery, required this.onClear});

  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: AppColors.gold,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'ບໍ່ພົບສິນຄ້າທີ່ຄົ້ນຫາ' : 'ບໍ່ມີສິນຄ້າ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ລອງປ່ຽນ scope ຫຼື ລ້າງຕົວກອງ',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: Icon(
                Icons.clear_all,
                size: 16,
                color: AppColors.gold,
              ),
              label: Text(
                'ລ້າງຕົວກອງ',
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
              color: AppColors.danger.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off,
              color: AppColors.danger,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ດຶງຂໍ້ມູນບໍ່ສຳເລັດ',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
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
              'ລອງໃໝ່',
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