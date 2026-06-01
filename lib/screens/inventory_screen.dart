import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/inventory_cache.dart';
import '../services/promotions_engine.dart';
import 'inventory_detail_screen.dart';
import '../components/ui_components.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const int _initialFetchLimit = 20;
  static const int _loadMoreStep = 10;
  static const int _maxLimit = 200;

  final _qtyFmt = NumberFormat('#,###.##', 'en_US');
  final _priceFmt = NumberFormat('#,###', 'en_US');
  final _scrollController = ScrollController();
  final _searchCtl = TextEditingController();

  List<InventoryItem> _items = const [];
  List<String> _salesWarehouses = const [];
  List<Promotion> _activePromos = const [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _query = '';

  Promotion? _activePromoForProduct(String code) {
    if (_activePromos.isEmpty) return null;
    final now = DateTime.now();
    final trimmed = code.trim();
    for (final p in _activePromos) {
      if (!isPromoActiveNow(p, now)) continue;
      if (p.triggerItemCode?.trim() == trimmed) return p;
    }
    return null;
  }

  final InventoryScope _scope = InventoryScope.company;
  bool _booted = false;
  int _currentLimit = _initialFetchLimit;
  bool _hasMore = true;
  Timer? _searchDebounce;
  int _searchSeq = 0;

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _runSearch(v);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
    final api = AppScope.of(context).api;
    final snap = await InventoryCache().read();
    if (mounted && snap != null && !snap.isEmpty) {
      setState(() {
        _items = snap.items.take(_initialFetchLimit).toList();
        _salesWarehouses = snap.salesWarehouses;
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }

    try {
      final promos = await api.fetchActivePromotions();
      if (mounted) setState(() => _activePromos = promos);
    } catch (e) {
      debugPrint('InventoryScreen: failed to fetch promotions -> $e');
    }

    await _runSearch('');
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    setState(() {
      _query = q;
      _currentLimit = _initialFetchLimit;
      _error = null;
      _hasMore = true;
      _loading = _items.isEmpty;
    });
    try {
      final api = AppScope.of(context).api;
      final rows = await api
          .searchInventory(q.trim(), limit: _initialFetchLimit)
          .timeout(const Duration(seconds: 15));
      if (seq != _searchSeq || !mounted) return;
      setState(() {
        _items = rows;
        _hasMore = rows.length >= _initialFetchLimit;
        _loading = false;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } catch (e) {
      if (seq != _searchSeq || !mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    if (_currentLimit >= _maxLimit) return;
    final nextLimit = (_currentLimit + _loadMoreStep).clamp(0, _maxLimit);
    setState(() => _loadingMore = true);
    final seq = _searchSeq;
    try {
      final api = AppScope.of(context).api;
      final rows = await api
          .searchInventory(_query.trim(), limit: nextLimit)
          .timeout(const Duration(seconds: 15));
      if (seq != _searchSeq || !mounted) return;
      setState(() {
        _items = rows;
        _currentLimit = nextLimit;
        _hasMore = rows.length >= nextLimit && nextLimit < _maxLimit;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 260) _loadMore();
    return false;
  }

  Future<void> _pullRefresh() => _runSearch(_query);

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

  ({int total, int available, int low, int out}) _stockSummary() {
    final lowStockCount = _items
        .where((i) => i.companyBalance > 0 && i.companyBalance <= i.salesMinimumStock)
        .length;
    final outOfStockCount = _items.where((i) => i.companyBalance <= 0).length;
    final availableCount = _items.where((i) => i.companyBalance > i.salesMinimumStock).length;
    return (
      total: _items.length,
      available: availableCount,
      low: lowStockCount,
      out: outOfStockCount,
    );
  }

  Widget _buildInventoryHeader() {
    final summary = _stockSummary();
    return Container(
      margin: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace2),
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: ThemeService.isDark ? 0.18 : 0.22),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 23),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ສິນຄ້າຄົງເຫຼືອ',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ກວດສອບຈຳນວນ, ລາຄາ ແລະ ສະຖານةສະຕັອກ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace4),
          Row(
            children: [
              Expanded(child: _InventoryStatTile(label: 'ທັງໝົດ', value: summary.total.toString(), color: Colors.white)),
              const SizedBox(width: kSpace2),
              Expanded(child: _InventoryStatTile(label: 'ພ້ອມຂາຍ', value: summary.available.toString(), color: AppColors.success)),
            ],
          ),
          const SizedBox(height: kSpace2),
          Row(
            children: [
              Expanded(child: _InventoryStatTile(label: 'ໃກ້ໝົດ', value: summary.low.toString(), color: AppColors.warning)),
              const SizedBox(width: kSpace2),
              Expanded(child: _InventoryStatTile(label: 'ໝົດແລ້ວ', value: summary.out.toString(), color: AppColors.danger)),
            ],
          ),
          const SizedBox(height: kSpace3),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadiusMd)),
            child: SearchField(
              controller: _searchCtl,
              hint: 'ຄົ້ນຫາ ຊື່ / ລະຫັດ / ຍີ່ຫໍ້…',
              onChanged: _onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardBg,
        onRefresh: _pullRefresh,
        child: TabletConstrain(maxWidth: 900, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const BrandedSpinner(label: 'ກຳລັງໂຫຼດສິນຄ້າ…');
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(kSpace5),
        children: [
          const SizedBox(height: 60),
          _ErrorCard(message: _error!, onRetry: () => _runSearch(_query)),
        ],
      );
    }

    return Column(
      children: [
        _buildInventoryHeader(),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyView(
                      hasQuery: _query.isNotEmpty,
                      onClear: () {
                        _searchCtl.clear();
                        _runSearch('');
                      },
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
                    sliver: SliverList.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        final promo = _activePromoForProduct(item.code);
                        return _RedesignedInventoryCard(
                          item: item,
                          fmt: _qtyFmt,
                          priceFmt: _priceFmt,
                          promoName: promo?.name,
                          onTap: () => _openDetail(item),
                        );
                      },
                    ),
                  ),
                  if (_hasMore)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 110),
                      sliver: SliverToBoxAdapter(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _loadingMore ? null : _loadMore,
                            borderRadius: BorderRadius.circular(kRadiusMd),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: kSpace3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_loadingMore) ...[
                                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                    const SizedBox(width: 8),
                                    Text('ກຳລັງໂຫຼດ…', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ] else ...[
                                    Icon(Icons.expand_more_rounded, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text('ໂຫຼດເພີ່ມ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------
// Redesigned inventory card
// -------------------------------
class _RedesignedInventoryCard extends StatelessWidget {
  const _RedesignedInventoryCard({
    required this.item,
    required this.fmt,
    required this.priceFmt,
    this.promoName,
    required this.onTap,
  });

  final InventoryItem item;
  final NumberFormat fmt;
  final NumberFormat priceFmt;
  final String? promoName;
  final VoidCallback onTap;

  Color _statusColor(InventoryItem item) {
    if (item.companyBalance <= 0) return AppColors.danger;
    if (item.companyBalance <= item.salesMinimumStock) return AppColors.warning;
    return AppColors.success;
  }

  String _statusLabel(InventoryItem item) {
    if (item.companyBalance <= 0) return 'ໝົດ';
    if (item.companyBalance <= item.salesMinimumStock) return 'ໃກ້ໝົດ';
    return 'ມີສິນຄ້າ';
  }

  double _stockPercentage() {
    if (item.salesMinimumStock <= 0) return 1.0;
    final ratio = item.companyBalance / item.salesMinimumStock;
    return ratio.clamp(0.0, 2.0) / 2.0; // Max 100% indicator at 2x min stock
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item);
    final statusLabel = _statusLabel(item);
    final unit = item.unitName ?? 'ອັນ';
    final isDark = ThemeService.isDark;
    final stockPercent = _stockPercentage();

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(kSpace4),
        accent: statusColor,
        radius: kRadiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with icon, title, status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product icon bubble (can be replaced with network image later)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withValues(alpha: 0.2), statusColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(kRadiusMd),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Icon(
                    Icons.inventory_rounded,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nameLo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.code, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            item.code,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (item.brandName != null && item.brandName!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.branding_watermark, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              item.brandName!,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpace2),
                StatusBadge(label: statusLabel, color: statusColor, size: StatusBadgeSize.small),
              ],
            ),

            // Promotion badge (if active)
            if (promoName != null && promoName!.isNotEmpty) ...[
              const SizedBox(height: kSpace3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(kRadiusSm),
                  border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.22), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer_rounded, size: 14, color: AppColors.brandOrange),
                    const SizedBox(width: 4),
                    Text('ໂປຣ: $promoName', style: const TextStyle(color: AppColors.brandOrange, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: kSpace4),

            // Stock indicator with progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ສະຕັອກຄົງເຫຼືອ',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${fmt.format(item.companyBalance)} $unit',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: stockPercent,
                    backgroundColor: AppColors.border,
                    color: statusColor,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ສະຕັອກຕຳ່ສຸດ: ${fmt.format(item.salesMinimumStock)} $unit',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 9),
                    ),
                    if (item.companyBalance > item.salesMinimumStock)
                      Icon(Icons.check_circle, size: 12, color: AppColors.success)
                    else if (item.companyBalance > 0)
                      Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.warning)
                    else
                      Icon(Icons.cancel_rounded, size: 12, color: AppColors.danger),
                  ],
                ),
              ],
            ),

            const SizedBox(height: kSpace4),
            Divider(height: 1, color: AppColors.border.withValues(alpha: isDark ? 0.25 : 0.45)),
            const SizedBox(height: kSpace4),

            // Price and action row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ລາຄາຂາຍ', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      if (item.salePriceKip > 0)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              priceFmt.format(item.salePriceKip),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('ກີບ', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                          ],
                        )
                      else
                        Text('ຍັງບໍ່ມີລາຄາ', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_right, size: 16, color: statusColor),
                      const SizedBox(width: 2),
                      Text('ລາຍລະອຽດ', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widgets remain unchanged or slightly polished
class _InventoryStatTile extends StatelessWidget {
  const _InventoryStatTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: isWhite ? Colors.white : color, shape: BoxShape.circle)),
          const SizedBox(width: kSpace2),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: 11, fontWeight: FontWeight.w700))),
          Text(value, style: TextStyle(color: isWhite ? Colors.white : color, fontSize: 16, fontWeight: FontWeight.w900, fontFeatures: kTabularFigures)),
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
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 30),
            ),
            const SizedBox(height: 14),
            Text(hasQuery ? 'ບໍ່ພົບສິນຄ້າທີ່ຄົ້ນຫາ' : 'ບໍ່ມີສິນຄ້າ', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('ລອງປ່ຽນ scope ຫຼື ລ້າງຕົວກອງ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.clear_all, size: 16, color: AppColors.gold),
              label: Text('ລ້າງຕົວກອງ', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off, color: AppColors.danger, size: 26),
          ),
          const SizedBox(height: 12),
          Text('ດຶງຂໍ້ມູນບໍ່ສຳເລັດ', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, size: 17, color: AppColors.bg),
            label: Text('ລອງໃໝ່', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }
}