// Standalone "Request Special Price" flow — replaces the inline cart-line
// request that used to live in create_order_screen. Salespeople come here
// FIRST, request a special price for a (customer, product) pair, wait for
// manager approval, then create the sale order normally — the approved
// price is auto-applied at cart-add time.
//
// Backend: POST /api/price-requests with cart_number=NULL.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/inventory_cache.dart';

class PriceRequestScreen extends StatefulWidget {
  const PriceRequestScreen({super.key});

  @override
  State<PriceRequestScreen> createState() => _PriceRequestScreenState();
}

class _PriceRequestScreenState extends State<PriceRequestScreen> {
  final _moneyFmt = NumberFormat('#,###.##', 'en_US');
  final _cache = InventoryCache();

  List<Customer> _customers = const [];
  List<InventoryItem> _items = const [];
  bool _loading = true;
  bool _submitting = false;

  Customer? _customer;
  InventoryItem? _item;
  final _priceCtl = TextEditingController();
  final _reasonCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _priceCtl.dispose();
    _reasonCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final api = AppScope.of(context).api;
    final snap = await _cache.read();
    if (snap != null && !snap.isEmpty && mounted) {
      setState(() => _items = snap.items);
    }
    try {
      final customers = await api.listCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('ໂຫຼດລູກຄ້າບໍ່ສຳເລັດ: $e');
    }
  }

  bool get _canSubmit {
    if (_customer == null || _item == null) return false;
    // Requestor only declares customer + item + reason. The approver sets
    // the price at decision time, so we no longer gate on a price input.
    if (_reasonCtl.text.trim().isEmpty) return false;
    return true;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SimplePickerSheet<Customer>(
        title: 'ເລືອກລູກຄ້າ',
        items: _customers,
        labelOf: (c) => c.name,
        subOf: (c) => c.phone ?? c.groupName ?? '',
        codeOf: (c) => c.id,
      ),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickItem() async {
    final picked = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SimplePickerSheet<InventoryItem>(
        title: 'ເລືອກສິນຄ້າ',
        items: _items,
        labelOf: (it) => it.nameLo,
        subOf: (it) => '${it.code} · ${_moneyFmt.format(it.salePriceKip)} ກີບ',
        codeOf: (it) => it.code,
      ),
    );
    if (picked == null) return;
    setState(() {
      _item = picked;
      _priceCtl.clear();
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await AppScope.of(context).api.createPriceRequest(
            customerCode: _customer!.id,
            itemCode: _item!.code,
            originalPrice: _item!.salePriceKip,
            reason: _reasonCtl.text.trim(),
          );
      if (!mounted) return;
      _toast('ສົ່ງຄຳຂໍແລ້ວ ✓ ລໍຖ້າຜູ້ຈັດການອະນຸມັດລາຄາ');
      setState(() {
        _item = null;
        _priceCtl.clear();
        _reasonCtl.clear();
      });
    } catch (e) {
      if (mounted) _toast('ຜິດພາດ: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'ຂໍລາຄາພິເສດ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: _loading
          ? const BrandedSpinner(label: 'ກຳລັງໂຫຼດຂໍ້ມູນ…')
          : TabletConstrain(child: _buildBody()),
      bottomNavigationBar:
          _loading ? null : TabletConstrain(child: _buildSubmitBar()),
    );
  }

  Widget _buildBody() {
    final item = _item;
    return FadeInSlide(
      duration: const Duration(milliseconds: 500),
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace5),
        children: [
          // Hero card explaining the flow.
          HeroPanel(
            colors: const [AppColors.brandOrange, AppColors.brandOrangeDark],
            padding: const EdgeInsets.fromLTRB(
                kSpace5, kSpace4, kSpace5, kSpace5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                  child: const Icon(
                    Icons.price_change_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: kSpace3),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ຂໍລາຄາພິເສດກ່ອນ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ເມື່ອຜູ້ຈັດການອະນຸມັດ, ລະບົບຈະໃຊ້ລາຄາໃໝ່ໃຫ້ອັດຕະໂນມັດເມື່ອເພີ່ມສິນຄ້ານີ້ໃຫ້ລູກຄ້ານີ້ໃນ Sale Order.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpace4),
          _pickerRow(
            icon: Icons.person_rounded,
            label: 'ລູກຄ້າ',
            value: _customer?.name,
            subValue: _customer?.phone ?? _customer?.groupName,
            onTap: _pickCustomer,
          ),
          const SizedBox(height: kSpace2),
          _pickerRow(
            icon: Icons.inventory_2_rounded,
            label: 'ສິນຄ້າ',
            value: item?.nameLo,
            subValue: item == null
                ? null
                : '${item.code} · ລາຄາເດີມ ${_moneyFmt.format(item.salePriceKip)} ກີບ',
            onTap: _items.isEmpty ? null : _pickItem,
            disabled: _items.isEmpty,
            disabledHint: 'ກຳລັງໂຫຼດສິນຄ້າ…',
          ),
          const SizedBox(height: kSpace4),
          const InlineBanner(
            kind: BannerKind.info,
            message:
                'ຜູ້ຈັດການຈະເປັນຜູ້ກຳນົດລາຄາໃໝ່ — ກະລຸນາໃສ່ເຫດຜົນເພື່ອພິຈາລະນາ',
          ),
          const SizedBox(height: kSpace3),
          TextField(
            controller: _reasonCtl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              labelText: 'ເຫດຜົນ *',
              hintText: 'ເຊັ່ນ: ລູກຄ້າ VIP, ໂປຣ, ສິນຄ້າເກົ່າ…',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required String? value,
    String? subValue,
    required VoidCallback? onTap,
    bool disabled = false,
    String? disabledHint,
  }) {
    final active = value != null;
    return SurfaceCard(
      onTap: onTap,
      padding:
          const EdgeInsets.fromLTRB(kSpace4, kSpace3 + 2, kSpace3, kSpace3 + 2),
      child: Row(
        children: [
          IconBubble(
            icon: icon,
            color: active ? AppColors.primary : AppColors.textMuted,
            size: BubbleSize.md,
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ??
                      (disabled ? (disabledHint ?? '—') : 'ກົດເພື່ອເລືອກ'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        active ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                if (subValue != null && subValue.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    final enabled = _canSubmit && !_submitting;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: kTouchTargetLg,
        child: DecoratedBox(
          decoration: enabled
              ? posActionDecoration(radius: kRadiusLg)
              : BoxDecoration(
                  color: AppColors.cardElev,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border.all(color: AppColors.border),
                ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadiusLg),
              onTap: enabled ? _submit : null,
              child: Center(
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFFFFFFFF),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            enabled ? Icons.send : Icons.lock_outline,
                            color: enabled
                                ? const Color(0xFFFFFFFF)
                                : AppColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            enabled
                                ? 'ສົ່ງຄຳຂໍ'
                                : (_customer == null
                                    ? 'ເລືອກລູກຄ້າ'
                                    : _item == null
                                        ? 'ເລືອກສິນຄ້າ'
                                        : (double.tryParse(
                                                      _priceCtl.text.trim(),
                                                    ) ??
                                                    0) <=
                                                0
                                            ? 'ໃສ່ລາຄາໃໝ່'
                                            : _reasonCtl.text.trim().isEmpty
                                                ? 'ໃສ່ເຫດຜົນ'
                                                : 'ລາຄາໃໝ່ຕ້ອງຕ່ຳກວ່າເດີມ'),
                            style: TextStyle(
                              color: enabled
                                  ? const Color(0xFFFFFFFF)
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimplePickerSheet<T> extends StatefulWidget {
  const _SimplePickerSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.subOf,
    required this.codeOf,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T) subOf;
  final String Function(T) codeOf;

  @override
  State<_SimplePickerSheet<T>> createState() => _SimplePickerSheetState<T>();
}

class _SimplePickerSheetState<T> extends State<_SimplePickerSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((it) {
            final l = widget.labelOf(it).toLowerCase();
            final s = widget.subOf(it).toLowerCase();
            final c = widget.codeOf(it).toLowerCase();
            return l.contains(q) || s.contains(q) || c.contains(q);
          }).toList();
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    Text(
                      '${filtered.length}',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    hintText: 'ຄົ້ນຫາ…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final it = filtered[i];
                    return Material(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context, it),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.labelOf(it),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              if (widget.subOf(it).isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subOf(it),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}