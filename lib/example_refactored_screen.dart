// EXAMPLE: How to Use New UI/UX Components
// This file demonstrates how to refactor an existing screen to use the new
// component library. Shows before/after patterns and best practices.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../app_theme.dart';
import '../components/dialog_utils.dart';
import '../components/ui_components.dart';
import '../models/models.dart';

// REFACTORED EXAMPLE: Orders Screen with new components
// This demonstrates how to use the UI component library for a production screen.

class OrdersScreenRefactored extends StatefulWidget {
  const OrdersScreenRefactored({super.key});

  @override
  State<OrdersScreenRefactored> createState() => _OrdersScreenRefactoredState();
}

class _OrdersScreenRefactoredState extends State<OrdersScreenRefactored> {
  late Future<List<SaleOrder>> _future;
  String _filter = 'ALL';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = AppScope.of(context).api.listOrders();
  }

  void _reload() async {
    try {
      setState(() => _future = AppScope.of(context).api.listOrders());
      AppSnackBars.showSuccess(context, 'ຂໍ້ມູນໂຫລດໃໝ່ສຳເລັດ');
    } catch (e) {
      AppSnackBars.showError(context, 'ບໍ່ສາມາດໂຫລດຂໍ້ມູນໄດ້');
    }
  }

  Future<void> _deleteOrder(SaleOrder order) async {
    final confirmed = await AppDialogs.showConfirm(
      context: context,
      title: 'ລຶບລາຍການ?',
      message: 'ລາຍການ #${order.docNo} ຈະຖືກລຶບຖາວອນ',
      isDangerous: true,
    );

    if (confirmed && mounted) {
      try {
        // await AppScope.of(context).api.deleteOrder(order.id);
        AppSnackBars.showSuccess(context, 'ລົບລາຍການສຳເລັດ');
        _reload();
      } catch (e) {
        AppSnackBars.showError(context, 'ບໍ່ສາມາດລຶບລາຍການ');
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID':
      case 'COMPLETED':
        return AppColors.success;
      case 'SCHEDULED':
      case 'SHIPPED':
        return AppColors.info;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PAID':
        return 'ຈ່າຍແລ້ວ';
      case 'COMPLETED':
        return 'ຮັບເງິນສຳເລັດ';
      case 'SCHEDULED':
      case 'SHIPPED':
        return 'ຈັດຖ້ຽວ';
      case 'CANCELLED':
        return 'ຍົກເລີກ';
      default:
        return 'ລໍຖ້າຮັບເງິນ';
    }
  }

  List<SaleOrder> _filterOrders(List<SaleOrder> orders) {
    var result = orders;

    // Filter by status
    if (_filter != 'ALL') {
      result = result.where((o) => o.status == _filter).toList();
    }

    // Filter by search query
    if (_query.isNotEmpty) {
      result = result
          .where((o) =>
              (o.docNo ?? '').toLowerCase().contains(_query.toLowerCase()) ||
              (o.customer?.name ?? '')
                  .toLowerCase()
                  .contains(_query.toLowerCase()))
          .toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<List<SaleOrder>>(
        future: _future,
        builder: (context, snap) {
          // Loading state
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonListPlaceholder();
          }

          // Error state
          if (snap.hasError) {
            return ErrorState(
              message: 'ບໍ່ສາມາດໂຫລດລາຍການ',
              details: snap.error.toString(),
              onRetry: _reload,
            );
          }

          final allOrders = snap.data ?? [];
          final filtered = _filterOrders(allOrders);

          // Empty state
          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'ບໍ່ມີລາຍການ',
              subtitle: _query.isNotEmpty
                  ? 'ບໍ່ພົບຜົນລະຫວ່າງຊອກຫາ'
                  : 'ທ່ານຍັງບໍ່ມີລາຍການຂາຍ',
              actionLabel: 'ສ້າງລາຍການ',
              onAction:
                  _query.isEmpty ? () => _handleCreateOrder() : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () => Future.sync(_reload),
            color: AppColors.primary,
            child: ListView(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(kSpace4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ຊອກຫາລາຍການ...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),

                // Filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                  child: Wrap(
                    spacing: kSpace2,
                    children: [
                      _FilterChip(
                        label: 'ທັງໝົດ',
                        selected: _filter == 'ALL',
                        onTap: () => setState(() => _filter = 'ALL'),
                      ),
                      _FilterChip(
                        label: 'ລໍຖ້າ',
                        selected: _filter == 'PENDING',
                        onTap: () => setState(() => _filter = 'PENDING'),
                        color: AppColors.warning,
                      ),
                      _FilterChip(
                        label: 'ຈ່າຍແລ້ວ',
                        selected: _filter == 'PAID',
                        onTap: () => setState(() => _filter = 'PAID'),
                        color: AppColors.success,
                      ),
                      _FilterChip(
                        label: 'ຍົກເລີກ',
                        selected: _filter == 'CANCELLED',
                        onTap: () => setState(() => _filter = 'CANCELLED'),
                        color: AppColors.danger,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: kSpace4),

                // Order list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: kSpace3),
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return _OrderCard(
                        order: order,
                        statusColor: _statusColor(order.status),
                        statusLabel: _statusLabel(order.status),
                        onTap: () => _handleOrderTap(order),
                        onDelete: () => _deleteOrder(order),
                      );
                    },
                  ),
                ),

                const SizedBox(height: kSpace4),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleCreateOrder,
        child: Icon(Icons.add_rounded),
      ),
    );
  }

  void _handleOrderTap(SaleOrder order) {
    // Navigate to order detail
    AppSnackBars.showInfo(context, 'Opening order #${order.docNo}');
  }

  void _handleCreateOrder() {
    // Navigate to create order screen
    AppSnackBars.showInfo(context, 'Create order feature coming soon');
  }
}

/// Individual order card component
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
    required this.onDelete,
  });

  final SaleOrder order;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat('#,###.##', 'en_US');

    return ElevatedCard(
      onTap: onTap,
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${order.docNo}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: kSpace1),
                    Text(
                      order.customer?.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: statusLabel,
                color: statusColor,
              ),
            ],
          ),

          const SizedBox(height: kSpace3),

          // Amount and date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ຈໍານວນເງິນ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '${moneyFmt.format(order.total)} ກີບ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ວັນທີ່',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Action buttons
          const SizedBox(height: kSpace3),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  onPressed: onTap,
                  label: 'ເບິ່ງ',
                  isFullWidth: true,
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                child: DangerButton(
                  onPressed: onDelete,
                  label: 'ລຶບ',
                  isFullWidth: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final fmt = DateFormat('dd/MM HH:mm');
    return fmt.format(dt);
  }
}

/// Filter chip component
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
      side: BorderSide(
        color: selected ? color : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: selected ? color : AppColors.textMuted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BEFORE/AFTER COMPARISON
// ─────────────────────────────────────────────────────────────────────────────

/// BEFORE: Original button code (repetitive and inconsistent)
/*
FilledButton(
  onPressed: _isLoading ? null : _handleSubmit,
  style: FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    minimumSize: const Size(double.infinity, 46),
  ),
  child: _isLoading
      ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        )
      : Text('Save'),
)
*/

/// AFTER: Using PrimaryButton component
/*
PrimaryButton(
  onPressed: _handleSubmit,
  label: 'Save',
  isLoading: _isLoading,
  isFullWidth: true,
)
*/

/// ─────────────────────────────────────────────────────────────────────────────

/// BEFORE: Raw form input with manual validation display
/*
TextFormField(
  decoration: InputDecoration(
    labelText: 'Customer',
    hintText: 'Enter customer name',
    prefixIcon: Icon(Icons.person),
    errorText: _nameError,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Please enter name';
    return null;
  },
)
*/

/// AFTER: Using FormInput component
/*
FormInput(
  label: 'Customer',
  hint: 'Enter customer name',
  prefixIcon: Icons.person,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Please enter name';
    return null;
  },
)
*/

/// ─────────────────────────────────────────────────────────────────────────────

/// BEFORE: Manual empty state rendering
/*
if (items.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        FilledButton(onPressed: _create, child: Text('Create')),
      ],
    ),
  );
}
*/

/// AFTER: Using EmptyState component
/*
if (items.isEmpty) {
  return EmptyState(
    icon: Icons.inbox,
    title: 'No items',
    actionLabel: 'Create',
    onAction: _create,
  );
}
*/
