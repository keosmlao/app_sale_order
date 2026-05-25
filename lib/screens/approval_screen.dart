import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  final _moneyFmt = NumberFormat('#,###', 'en_US');
  final _dateFmt = DateFormat('dd/MM HH:mm');
  Future<List<PriceRequest>>? _future;
  String _statusFilter = 'pending';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _fetch();
  }

  Future<List<PriceRequest>> _fetch() {
    return AppScope.of(context).api.listPriceRequests(status: _statusFilter);
  }

  Future<void> _reload() async {
    setState(() => _future = _fetch());
    await _future;
  }

  void _setStatus(String s) {
    setState(() {
      _statusFilter = s;
      _future = _fetch();
    });
  }

  Future<void> _decide(PriceRequest req, String action) async {
    final isApprove = action == 'approve';
    final noteCtl = TextEditingController();
    final priceCtl = TextEditingController();
    // Approve dialog needs a price input — the manager decides the number,
    // not the requestor. Reject keeps the original single-field shape.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final priceText = priceCtl.text.trim();
          final price = double.tryParse(priceText);
          final priceOk = !isApprove ||
              (price != null && price > 0 && price < req.originalPrice);
          final pctOff = isApprove && price != null && price > 0
              ? ((req.originalPrice - price) / req.originalPrice) * 100
              : null;
          return AlertDialog(
            title: Text(isApprove ? 'ອະນຸມັດຄຳຂໍ' : 'ປະຕິເສດຄຳຂໍ'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApprove
                      ? 'ກຳນົດລາຄາໃໝ່ສຳລັບ "${req.itemName ?? req.itemCode}" (ປົກກະຕິ ${_moneyFmt.format(req.originalPrice)} ກີບ)'
                      : 'ປະຕິເສດຄຳຂໍຂອງ "${req.requestorName ?? req.requestorCode}"?',
                  style: const TextStyle(fontSize: 13),
                ),
                if (req.reason != null && req.reason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ເຫດຜົນ: ${req.reason}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                if (isApprove) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      labelText: 'ລາຄາທີ່ອະນຸມັດ (ກີບ) *',
                      hintText:
                          'ຕ້ອງຕ່ຳກວ່າ ${_moneyFmt.format(req.originalPrice)}',
                      prefixIcon: const Icon(Icons.attach_money),
                      helperText: pctOff == null
                          ? null
                          : pctOff > 0
                              ? 'ສ່ວນຫຼຸດ ${pctOff.toStringAsFixed(1)}%'
                              : 'ລາຄາສູງເກີນ — ຕ້ອງຕ່ຳກວ່າລາຄາເດີມ',
                      helperStyle: TextStyle(
                        color: pctOff != null && pctOff > 0
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isApprove ? 'ໝາຍເຫດ (optional)' : 'ເຫດຜົນ *',
                    hintText: isApprove
                        ? 'ເຊັ່ນ: ລູກຄ້າປະຈຳ'
                        : 'ເຊັ່ນ: ສ່ວນຫຼຸດສູງເກີນ',
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
                onPressed: priceOk ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isApprove ? AppColors.success : AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: Text(isApprove ? 'ອະນຸມັດ' : 'ປະຕິເສດ'),
              ),
            ],
          );
        },
      ),
    );
    if (confirm != true || !mounted) return;
    final note = noteCtl.text.trim();
    if (!isApprove && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ກະລຸນາໃສ່ເຫດຜົນປະຕິເສດ'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(12),
        ),
      );
      return;
    }
    final approvedPrice = isApprove
        ? double.tryParse(priceCtl.text.trim())
        : null;
    try {
      await AppScope.of(context).api.decidePriceRequest(
        id: req.id,
        action: action,
        note: note.isEmpty ? null : note,
        approvedPrice: approvedPrice,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApprove ? 'ອະນຸມັດສຳເລັດ ✓' : 'ປະຕິເສດສຳເລັດ ✓'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
      _reload();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.cardBg,
      onRefresh: _reload,
      child: TabletConstrain(
        maxWidth: 840,
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: FutureBuilder<List<PriceRequest>>(
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
                  final list = snap.data ?? [];
                  if (list.isEmpty) return _buildEmpty();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => FadeInSlide(
                      duration: Duration(milliseconds: 300 + (i < 6 ? i * 80 : 480)),
                      delay: Duration(milliseconds: i < 6 ? i * 50 : 300),
                      child: _buildCard(list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _filterPill('ລໍຖ້າ', 'pending', AppColors.warning),
          const SizedBox(width: 6),
          _filterPill('ອະນຸມັດແລ້ວ', 'approved', AppColors.success),
          const SizedBox(width: 6),
          _filterPill('ປະຕິເສດ', 'rejected', AppColors.danger),
        ],
      ),
    );
  }

  Widget _filterPill(String label, String key, Color color) {
    final selected = _statusFilter == key;
    return Expanded(
      child: Material(
        color: selected ? color.withValues(alpha: 0.15) : AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _setStatus(key),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : AppColors.slate500,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final label = _statusFilter == 'pending'
        ? 'ບໍ່ມີຄຳຂໍລໍຖ້າ — ດີຫຼາຍ! 🎉'
        : _statusFilter == 'approved'
            ? 'ຍັງບໍ່ມີຄຳຂໍທີ່ອະນຸມັດ'
            : 'ຍັງບໍ່ມີຄຳຂໍທີ່ປະຕິເສດ';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.success.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(PriceRequest req) {
    final color = _statusColor(req.status);
    final pending = req.status == 'pending';
    final saved = req.discount * req.qty;
    final cartLabel = req.isStandalone
        ? 'ກ່ອນ Order'
        : '#${req.cartNumber}';
    return GlassCard(
      radius: kRadiusMd,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — glowing status bar + customer + cart/standalone + status pill.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.customerName ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: req.isStandalone
                                  ? AppColors.warning.withValues(alpha: 0.18)
                                  : AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cartLabel,
                              style: TextStyle(
                                color: req.isStandalone
                                    ? AppColors.warning
                                    : AppColors.gold,
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.person_outline,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              req.requestorName ?? req.requestorCode,
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _statusLabel(req.status),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Item + price comparison
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.itemName ?? req.itemCode,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${req.itemCode}${req.unitName != null ? " · ${req.unitName}" : ""} · qty ${req.qty}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _priceBox(
                        label: 'ປະຈຸບັນ',
                        value: req.originalPrice,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _priceBox(
                        label: 'ຂໍໃໝ່',
                        value: req.requestedPrice,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '−${req.discountPct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '−${_moneyFmt.format(saved)}',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (req.reason != null && req.reason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote,
                          color: AppColors.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            req.reason!,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'ຂໍເມື່ອ ${_dateFmt.format(req.requestedAt.toLocal())}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                if (!pending && req.approverName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ໂດຍ ${req.approverName} · ${req.decidedAt != null ? _dateFmt.format(req.decidedAt!.toLocal()) : ""}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (req.approverNote != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '“${req.approverNote}”',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (pending)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.slate100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _decide(req, 'reject'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.close,
                                color: AppColors.danger,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ປະຕິເສດ',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.slate100),
                  Expanded(
                    child: Material(
                      color: AppColors.success.withValues(alpha: 0.08),
                      child: InkWell(
                        onTap: () => _decide(req, 'approve'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check,
                                color: AppColors.success,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ອະນຸມັດ',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _priceBox({
    required String label,
    // Null = "no price set yet" (pending request that the approver hasn't
    // decided on). Renders as an em-dash to make the empty state visible.
    required double? value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value == null ? '—' : _moneyFmt.format(value),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'ອະນຸມັດແລ້ວ';
      case 'rejected':
        return 'ປະຕິເສດ';
      default:
        return 'ລໍຖ້າ';
    }
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
        borderRadius: BorderRadius.circular(kRadiusMd),
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
              size: 26,
              color: AppColors.danger,
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
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('ລອງໃໝ່'),
          ),
        ],
      ),
    );
  }
}