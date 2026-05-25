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
      final result = await api.fetchStockBalance(
        [code],
        warehouses: _isSales ? widget.salesWarehouses : null,
      );
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
    if (v <= 0) return 'Out';
    if (v <= 5) return 'Low';
    return 'In stock';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'ລາຍລະອຽດສິນຄ້າ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'ໂຫຼດໃໝ່',
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.refresh, color: AppColors.gold),
          ),
        ],
      ),
      body: TabletConstrain(
        child: FadeInSlide(
          duration: const Duration(milliseconds: 500),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
          _sectionLabel('PRODUCT'),
          const SizedBox(height: 8),
          _ProductCard(item: item, isSales: _isSales),
          const SizedBox(height: 18),
          _sectionLabel('STOCK'),
          const SizedBox(height: 8),
          _buildBalanceSection(),
          const SizedBox(height: 18),
          _sectionLabel('DETAILS'),
          const SizedBox(height: 8),
          _DetailsCard(item: item, fmt: _fmt),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
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
          text,
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

  Widget _buildBalanceSection() {
    if (_loading) {
      return _Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
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
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
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
    return GlassCard(
      radius: 14,
      padding: EdgeInsets.zero,
      child: child,
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.isSales});
  final InventoryItem item;
  final bool isSales;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.goldBright, AppColors.gold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.inventory_2,
                  size: 20,
                  color: AppColors.bg,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nameLo,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        height: 1.25,
                      ),
                    ),
                    if (item.nameEng != null && item.nameEng!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.nameEng!,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  item.code,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ScopeBadge(isSales: isSales),
            ],
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
    final color = isSales ? AppColors.gold : AppColors.info;
    final icon = isSales
        ? Icons.storefront_outlined
        : Icons.business_outlined;
    final label = isSales ? 'ຂາຍ' : 'ບໍລິສັດ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardElev, AppColors.gold.withValues(alpha: 0.06)],
        ),
      ),
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
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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
          const SizedBox(height: 18),
          if (balance == null)
            Text(
              'ບໍ່ມີຂໍ້ມູນ',
              style: TextStyle(color: AppColors.textMuted),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  qtyFmt.format(qty),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  balance!.unitCode ?? unitFallback ?? '',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (balance!.locations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),
              Row(
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
                    isSales
                        ? 'ບ່ອນຈັດເກັບ (ສາງຂາຍ)'
                        : 'ບ່ອນຈັດເກັບ · ${balance!.locations.length}',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < balance!.locations.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == balance!.locations.length - 1 ? 0 : 8,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warehouse.isEmpty ? 'ບໍ່ລະບຸສາງ' : warehouse,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location.isEmpty ? 'ບໍ່ລະບຸບ່ອນຈັດເກັບ' : location,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                qtyFmt.format(loc.balanceQty),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
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
        item.itemStatus == 0
            ? 'ໃຊ້ງານ'
            : (item.itemStatus?.toString()),
      ),
    ];

    return _Card(
      child: Column(
        children: List.generate(rows.length, (i) {
          final r = rows[i];
          final isLast = i == rows.length - 1;
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                  width: 110,
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
      ),
    );
  }
}

class _Kv {
  const _Kv(this.key, this.value);
  final String key;
  final String? value;
}