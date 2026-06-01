import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';

class InventoryDetailScreen extends StatefulWidget {
  const InventoryDetailScreen({
    super.key,
    required this.item,
    this.scope = InventoryScope.company,
    this.salesWarehouses = const [],
  });

  final InventoryItem item;
  final InventoryScope scope;
  final List<String> salesWarehouses;

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  final _fmt = NumberFormat('#,###.##', 'en_US');
  final _qtyFmt = NumberFormat('#,###.####', 'en_US');

  StockBalance? _balance;
  bool _loading = true;
  String? _error;
  bool _booted = false;

  bool get _isSales => widget.scope == InventoryScope.sales;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_booted) {
      _booted = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final code = widget.item.code;
      final result = await api.fetchStockBalance([
        code,
      ], warehouses: _isSales ? widget.salesWarehouses : null);
      if (!mounted) return;
      setState(() {
        _balance = result.isEmpty ? null : result.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _balanceColor(double v) {
    if (v <= 0) return AppColors.danger;
    if (v <= 5) return AppColors.warning;
    return AppColors.success;
  }

  String _balanceLabel(double v) {
    if (v <= 0) return 'ໝົດແລ້ວ';
    if (v <= 5) return 'ໃກ້ໝົດ';
    return 'ພ້ອມຂາຍ';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: kSpace3),
          child: IconButton(
            tooltip: 'ກັບຄືນ',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        title: const Text(
          'ລາຍລະອຽດສິນຄ້າ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: kSpace3),
            child: IconButton(
              tooltip: 'ໂຫຼດໃໝ່',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
      body: TabletConstrain(
        child: FadeInSlide(
          duration: const Duration(milliseconds: 500),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              kSpace4,
              kSpace3,
              kSpace4,
              kSpace6,
            ),
            children: [
              _ProductHero(item: item, isSales: _isSales),
              const SizedBox(height: kSpace3),
              _buildBalanceSection(),
              const SizedBox(height: kSpace3),
              _DetailsCard(item: item, fmt: _fmt),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSection() {
    if (_loading) {
      return _Card(
        child: const Padding(
          padding: EdgeInsets.all(kSpace6),
          child: Center(child: BrandedSpinner(label: 'ກຳລັງໂຫຼດສະຕັອກ…')),
        ),
      );
    }
    if (_error != null) {
      return _Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off,
                  size: 24,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh, size: 16, color: AppColors.bg),
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
        ),
      );
    }

    final title = _isSales ? 'ຄົງເຫຼືອສຳລັບຂາຍ' : 'ຄົງເຫຼືອທັງບໍລິສັດ';
    final subtitle = _isSales
        ? (widget.salesWarehouses.isEmpty
              ? 'ບໍ່ມີສາງຂາຍຖືກກຳນົດ'
              : 'ສາງ ${widget.salesWarehouses.join(", ")}')
        : 'ລວມທຸກສາງ';

    return _BalanceCard(
      title: title,
      subtitle: subtitle,
      balance: _balance,
      isSales: _isSales,
      unitFallback: widget.item.unitName,
      qtyFmt: _qtyFmt,
      balanceColor: _balanceColor,
      balanceLabel: _balanceLabel,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: kRadiusMd,
      padding: EdgeInsets.zero,
      child: child,
    );
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.item, required this.isSales});
  final InventoryItem item;
  final bool isSales;

  @override
  Widget build(BuildContext context) {
    final initial = item.nameLo.trim().isEmpty ? '?' : item.nameLo.trim()[0];

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
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
                      item.nameLo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.nameEng != null && item.nameEng!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.nameEng!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
              _HeroChip(icon: Icons.tag_rounded, label: item.code),
              if (item.brandName != null && item.brandName!.isNotEmpty)
                _HeroChip(
                  icon: Icons.local_offer_rounded,
                  label: item.brandName!,
                ),
              _ScopeBadge(isSales: isSales),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.78), size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.isSales});
  final bool isSales;

  @override
  Widget build(BuildContext context) {
    final color = isSales ? AppColors.warning : AppColors.info;
    final icon = isSales ? Icons.storefront_outlined : Icons.business_outlined;
    final label = isSales ? 'ຂາຍ' : 'ບໍລິສັດ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.subtitle,
    required this.balance,
    required this.isSales,
    required this.unitFallback,
    required this.qtyFmt,
    required this.balanceColor,
    required this.balanceLabel,
  });

  final String title;
  final String subtitle;
  final StockBalance? balance;
  final bool isSales;
  final String? unitFallback;
  final NumberFormat qtyFmt;
  final Color Function(double) balanceColor;
  final String Function(double) balanceLabel;

  @override
  Widget build(BuildContext context) {
    final qty = balance?.balanceQty ?? 0;
    final color = balanceColor(qty);
    final label = balanceLabel(qty);
    return SurfaceCard(
      padding: const EdgeInsets.all(kSpace4),
      radius: kRadiusMd,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBubble(
                icon: Icons.warehouse_rounded,
                color: color,
                size: BubbleSize.sm,
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (balance != null) _StatusBadge(color: color, label: label),
            ],
          ),
          const SizedBox(height: kSpace4),
          if (balance == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(kSpace3),
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(
                  alpha: ThemeService.isDark ? 0.30 : 0.72,
                ),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Text(
                'ບໍ່ມີຂໍ້ມູນ',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(kSpace3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: color.withValues(alpha: 0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      qtyFmt.format(qty),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                        height: 1,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  Text(
                    balance!.unitCode ?? unitFallback ?? '',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (balance!.locations.isNotEmpty) ...[
              const SizedBox(height: kSpace4),
              Row(
                children: [
                  Icon(Icons.place_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: kSpace2),
                  Text(
                    isSales
                        ? 'ບ່ອນຈັດເກັບ (ສາງຂາຍ)'
                        : 'ບ່ອນຈັດເກັບ · ${balance!.locations.length}',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpace2),
              for (int i = 0; i < balance!.locations.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == balance!.locations.length - 1 ? 0 : kSpace2,
                  ),
                  child: _LocationRow(
                    loc: balance!.locations[i],
                    qtyFmt: qtyFmt,
                    balanceColor: balanceColor,
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.loc,
    required this.qtyFmt,
    required this.balanceColor,
  });
  final StockLocation loc;
  final NumberFormat qtyFmt;
  final Color Function(double) balanceColor;

  @override
  Widget build(BuildContext context) {
    final warehouse = [
      loc.warehouse,
      loc.warehouseName,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' · ');
    final location = [
      loc.location,
      loc.locationName,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' · ');
    final color = balanceColor(loc.balanceQty);

    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(
          alpha: ThemeService.isDark ? 0.30 : 0.72,
        ),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Icon(Icons.inventory_rounded, color: color, size: 17),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warehouse.isEmpty ? 'ບໍ່ລະບຸສາງ' : warehouse,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  location.isEmpty ? 'ບໍ່ລະບຸບ່ອນຈັດເກັບ' : location,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                qtyFmt.format(loc.balanceQty),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  fontFeatures: kTabularFigures,
                ),
              ),
              if (loc.unitCode != null && loc.unitCode!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  loc.unitCode!,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusPill),
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
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.item, required this.fmt});
  final InventoryItem item;
  final NumberFormat fmt;

  String? _withCode(String? name, String? code) {
    final n = name?.trim();
    final c = code?.trim();
    if (n != null && n.isNotEmpty) {
      return c != null && c.isNotEmpty ? '$n ($c)' : n;
    }
    return c == null || c.isEmpty ? null : c;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_Kv>[
      _Kv('ຍີ່ຫໍ້', _withCode(item.brandName, item.brand)),
      _Kv('ໝວດສິນຄ້າ', _withCode(item.categoryName, item.category)),
      _Kv('ກຸ່ມໃຫຍ່', _withCode(item.groupMainName, item.groupMain)),
      _Kv('ໜ່ວຍ', item.unitName),
      _Kv(
        'ລາຄາຂາຍ',
        item.salePriceKip > 0 ? '${fmt.format(item.salePriceKip)} ກີບ' : null,
      ),
      _Kv(
        'ສະຖານະ',
        item.itemStatus == 0 ? 'ໃຊ້ງານ' : (item.itemStatus?.toString()),
      ),
    ];

    return SurfaceCard(
      padding: EdgeInsets.zero,
      radius: kRadiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpace4,
              kSpace4,
              kSpace4,
              kSpace2,
            ),
            child: Row(
              children: [
                IconBubble(
                  icon: Icons.list_alt_rounded,
                  color: AppColors.info,
                  size: BubbleSize.sm,
                ),
                const SizedBox(width: kSpace3),
                Text(
                  'ຂໍ້ມູນສິນຄ້າ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(rows.length, (i) {
            final r = rows[i];
            final isLast = i == rows.length - 1;
            return Container(
              padding: const EdgeInsets.fromLTRB(
                kSpace4,
                kSpace3,
                kSpace4,
                kSpace3,
              ),
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
                    width: 112,
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
                      (r.value == null || r.value!.isEmpty) ? '—' : r.value!,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Kv {
  const _Kv(this.key, this.value);
  final String key;
  final String? value;
}
