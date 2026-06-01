# app_sale_order UI/UX Design System Guide

## Overview

This document describes the enhanced UI/UX design system for the ODG Sales App. The system provides reusable components, consistent patterns, and best practices for building beautiful, responsive interfaces.

## Architecture

```
lib/
├── components/
│   ├── ui_components.dart        # Core UI components (buttons, inputs, cards, etc.)
│   └── dialog_utils.dart          # Dialog, bottom sheet, and snackbar utilities
├── app_theme.dart                 # Design tokens & theme definitions
└── screens/                        # Feature screens
```

## Design Tokens

### Color Palette

**Primary Brand Colors:**
- `AppColors.primary` - ODG Teal (#0F766E) - Main CTAs, active navigation, and focus states
- `AppColors.primaryDark` - Deep teal (#115E59) for pressed states
- `AppColors.primaryLight` - Bright teal (#14B8A6) for hero gradients and highlights
- `AppColors.accent` - Sales amber (#F59E0B) for promotions, attention, and secondary emphasis
- `AppColors.brandOrange` - Compatibility alias for the amber accent used by existing promotion UI

**Status Colors:**
- `AppColors.success` - Green (#24A148) for positive states
- `AppColors.warning` - Amber (#F59E0B) for caution/pending
- `AppColors.danger` - Red (#EF4444) for destructive actions
- `AppColors.info` - Sky Blue (#0EA5E9) for informational

**Neutral Colors:**
- `AppColors.bg` - Background fill (adaptive light/dark)
- `AppColors.cardBg` - Card/surface color
- `AppColors.border` - Border color
- `AppColors.textPrimary` - Body text
- `AppColors.textMuted` - Secondary/disabled text

### Spacing Scale

```dart
kSpace1 = 4px
kSpace2 = 8px
kSpace3 = 12px
kSpace4 = 16px
kSpace5 = 20px
kSpace6 = 24px
kSpace8 = 32px
kSpace10 = 40px
```

### Border Radius Scale

```dart
kRadiusSm = 8px
kRadiusMd = 12px
kRadiusLg = 16px
kRadiusXl = 20px
kRadius2xl = 28px
kRadiusPill = 999px
```

### Motion/Animation

```dart
kMotionFast = 180ms
kMotionMed = 260ms
kMotionSlow = 420ms
```

## Component Library

### 1. Buttons

#### PrimaryButton
Main call-to-action button for critical actions.

```dart
PrimaryButton(
  onPressed: () => _handleSubmit(),
  label: 'ບັນທຶກ',
  isLoading: _isLoading,
  isFullWidth: true,
  icon: Icons.save_rounded,
)
```

**Parameters:**
- `onPressed` - Button tap callback
- `label` - Button text
- `isLoading` - Show loading spinner
- `isFullWidth` - Stretch to full width
- `isDisabled` - Disable interaction
- `icon` - Optional leading icon

#### SecondaryButton
Secondary action button for less critical flows.

```dart
SecondaryButton(
  onPressed: () => _handleCancel(),
  label: 'ຍົກເລີກ',
  isFullWidth: true,
)
```

#### DangerButton
Destructive action button (delete, cancel order, etc.).

```dart
DangerButton(
  onPressed: () => _handleDelete(),
  label: 'ລຶບ',
  isFullWidth: false,
)
```

### 2. Form Inputs

#### FormInput
Standardized text input with label, hint, and validation.

```dart
FormInput(
  label: 'ຊື່ລູກຄ້າ',
  hint: 'ປ້ອນຊື່ລູກຄ້າ...',
  prefixIcon: Icons.person_rounded,
  controller: _nameController,
  keyboardType: TextInputType.text,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'ກະລຸນາປ້ອນຊື່';
    return null;
  },
  onChanged: (value) => setState(() => _name = value),
)
```

**Parameters:**
- `label` - Field label text
- `hint` - Placeholder text
- `prefixIcon` / `suffixIcon` - Leading/trailing icons
- `keyboardType` - Input type (text, number, email, etc.)
- `maxLines` - Line count (default 1)
- `validator` - Form field validator
- `obscureText` - Hide input (for passwords)
- `errorText` - Display error message

### 3. Status Badges

Display status indicators with semantic colors.

```dart
StatusBadge(
  label: 'ລໍຖ້າຮັບເງິນ',
  color: AppColors.warning,
  icon: Icons.clock_rounded,
  size: StatusBadgeSize.medium,
)
```

**Sizes:** `small`, `medium`, `large`

### 4. Card Components

#### ElevatedCard
Elevated card with shadow and inset content.

```dart
ElevatedCard(
  onTap: () => _handleCardTap(),
  padding: const EdgeInsets.all(kSpace4),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Card Title'),
      SizedBox(height: kSpace2),
      Text('Card content goes here'),
    ],
  ),
)
```

#### OutlinedCard
Card with border instead of elevation.

```dart
OutlinedCard(
  padding: const EdgeInsets.all(kSpace4),
  child: Text('Outlined card content'),
)
```

### 5. Empty & Error States

#### EmptyState
Friendly message for empty data lists.

```dart
EmptyState(
  icon: Icons.shopping_cart_rounded,
  title: 'ບໍ່ມີລາຍການ',
  subtitle: 'ທ່ານຍັງບໍ່ມີລາຍການຂາຍ',
  actionLabel: 'ສ້າງລາຍການໃໝ່',
  onAction: () => _handleCreate(),
)
```

#### ErrorState
Error message with retry option.

```dart
ErrorState(
  message: 'ເກີດຂໍ້ຜິດພາດ',
  details: 'ບໍ່ສາມາດໂຫລດຂໍ້ມູນ',
  onRetry: () => _reload(),
  retryLabel: 'ລອງໃໝ່',
)
```

### 6. Information Banners

Display inline alerts and informational messages.

```dart
InfoBanner(
  message: 'ສົ່ງໄປສຳເລັດແລ້ວ',
  type: BannerType.success,
  icon: Icons.check_circle_rounded,
)
```

**Types:** `info`, `warning`, `success`, `error`

### 7. Section Headers

Organize content with styled section headers.

```dart
SectionHeader(
  title: 'ລາຍການຂາຍວານຸ່ນ',
  icon: Icons.receipt_long_rounded,
  actionLabel: 'ເບິ່ງທັງໝົດ',
  onAction: () => _viewAll(),
)
```

### 8. Search Bar

Beautiful search input with optional filter.

```dart
SearchBar(
  placeholder: 'ຊອກຫາສິນຄ້າ...',
  onChanged: (value) => _handleSearch(value),
  onFilterTap: () => _showFilters(),
)
```

## Dialog & Modal Utilities

### Confirmation Dialog

```dart
final confirmed = await AppDialogs.showConfirm(
  context: context,
  title: 'ຢືນຢັນ',
  message: 'ທ່ານແນ່ໃຈບໍ?',
  confirmLabel: 'ຕົກລົງ',
  cancelLabel: 'ຍົກເລີກ',
  isDangerous: false,
);

if (confirmed) {
  // Handle confirmed action
}
```

### Alert Dialog

```dart
await AppDialogs.showAlert(
  context: context,
  title: 'ໝາຍເຫດ',
  message: 'ການດຳເນີນການສຳເລັດແລ້ວ',
  buttonLabel: 'ຕົກລົງ',
);
```

### Input Dialog

```dart
final input = await AppDialogs.showInputDialog(
  context: context,
  title: 'ປ້ອນຄຳເຫດຜົນ',
  hint: 'ເຫດຜົນສຳຫລັບການຍົກເລີກ...',
  submitLabel: 'ບັນທຶກ',
);
```

### Bottom Sheet Menu

```dart
final selected = await AppBottomSheets.showMenu<String>(
  context: context,
  title: 'ເລືອກຄຳສັ່ງ',
  items: [
    (label: 'ແກ້ไຂ', icon: Icons.edit, value: 'edit'),
    (label: 'ລົບ', icon: Icons.delete, value: 'delete'),
    (label: 'ສົ່ງ', icon: Icons.send, value: 'send'),
  ],
);
```

## Snackbar Utilities

Show contextual feedback messages:

```dart
AppSnackBars.showSuccess(context, 'ບັນທຶກສຳເລັດ');
AppSnackBars.showError(context, 'ເກີດຂໍ້ຜິດພາດ');
AppSnackBars.showWarning(context, 'ໝາຍເຫດ: ລາຍການນີ້ມີຄວາມສຳຄັນ');
AppSnackBars.showInfo(context, 'ຂໍ້ມູນເພີ່ມເຕີມ');
```

## Best Practices

### 1. Form Validation

Always provide clear validation feedback:

```dart
FormInput(
  label: 'ລະຫັດຜ່ານ',
  obscureText: true,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'ກະລຸນາປ້ອນລະຫັດຜ່ານ';
    if ((value?.length ?? 0) < 6) return 'ລະຫັດຜ່ານຕ້ອງໃຫຍ່ກວ່າ 6 ອັກສອນ';
    return null;
  },
)
```

### 2. Loading States

Always show loading feedback for async operations:

```dart
PrimaryButton(
  onPressed: _isSubmitting ? null : () => _submit(),
  label: 'ບັນທຶກ',
  isLoading: _isSubmitting,
)
```

### 3. Empty States

Never show blank screens - always provide context:

```dart
if (items.isEmpty) {
  return EmptyState(
    icon: Icons.inbox_rounded,
    title: 'ບໍ່ມີລາຍການ',
    subtitle: 'ເບິ່ງຄືວ່າທ່ານບໍ່ມີລາຍການຂະນະນີ້',
  );
}
```

### 4. Error Handling

Always provide actionable error messages:

```dart
catch (e) {
  AppSnackBars.showError(
    context,
    'ບໍ່ສາມາດບັນທຶກ: ${e.toString()}',
  );
}
```

### 5. Confirmation for Destructive Actions

Always confirm before deleting or critical changes:

```dart
onDelete: () async {
  final confirmed = await AppDialogs.showConfirm(
    context: context,
    title: 'ລຶບລາຍການ?',
    message: 'ການດຳເນີນການນີ້ບໍ່ສາມາດກັບຄືນໄດ້',
    isDangerous: true,
  );
  if (confirmed) {
    await _delete();
  }
}
```

## Integration Examples

### Example 1: Simple Order Form

```dart
import 'package:app_sale_order/components/ui_components.dart';
import 'package:app_sale_order/components/dialog_utils.dart';

class CreateOrderForm extends StatefulWidget {
  @override
  State<CreateOrderForm> createState() => _CreateOrderFormState();
}

class _CreateOrderFormState extends State<CreateOrderForm> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _customerController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      // Submit order
      AppSnackBars.showSuccess(context, 'ລາຍການບັນທຶກສຳເລັດ');
      Navigator.pop(context);
    } catch (e) {
      AppSnackBars.showError(context, 'ເກີດຂໍ້ຜິດພາດ: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ສ້າງລາຍການ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(kSpace4),
          children: [
            FormInput(
              label: 'ຊື່ລູກຄ້າ',
              controller: _customerController,
              prefixIcon: Icons.person_rounded,
              validator: (v) => v?.isEmpty ?? true ? 'ກະລຸນາໃສ່ຊື່' : null,
            ),
            SizedBox(height: kSpace4),
            FormInput(
              label: 'ຈໍານວນ',
              controller: _quantityController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.numbers,
              validator: (v) => v?.isEmpty ?? true ? 'ກະລຸນາໃສ່ຈໍານວນ' : null,
            ),
            SizedBox(height: kSpace6),
            PrimaryButton(
              onPressed: _submit,
              label: 'ບັນທຶກລາຍການ',
              isLoading: _isSubmitting,
              isFullWidth: true,
            ),
            SizedBox(height: kSpace2),
            SecondaryButton(
              onPressed: () => Navigator.pop(context),
              label: 'ຍົກເລີກ',
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
```

### Example 2: List with Empty State

```dart
class OrdersList extends StatefulWidget {
  @override
  State<OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<OrdersList> {
  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<Order>> _loadOrders() async {
    // Load from API
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Order>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonListPlaceholder();
        }

        if (snapshot.hasError) {
          return ErrorState(
            message: 'ບໍ່ສາມາດໂຫລດລາຍການ',
            onRetry: () => setState(() => _ordersFuture = _loadOrders()),
          );
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'ບໍ່ມີລາຍການ',
            subtitle: 'ເລີ່ມສ້າງລາຍການໃໝ່ໂດຍປະໂຫຍດວະກັນ',
            actionLabel: 'ສ້າງລາຍການ',
            onAction: () => _handleCreate(),
          );
        }

        return ListView.separated(
          itemCount: orders.length,
          separatorBuilder: (_, __) => SizedBox(height: kSpace2),
          itemBuilder: (context, index) {
            final order = orders[index];
            return ElevatedCard(
              onTap: () => _handleOrderTap(order),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.number),
                        SizedBox(height: kSpace1),
                        StatusBadge(
                          label: order.status,
                          color: _statusColor(order.status),
                        ),
                      ],
                    ),
                  ),
                  Text(order.total),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID':
        return AppColors.success;
      case 'PENDING':
        return AppColors.warning;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }
}
```

## Migration Guide

To update existing screens to use the new components:

1. **Replace button code:**
   ```dart
   // Old
   FilledButton(onPressed: () {}, child: Text('Save'))
   
   // New
   PrimaryButton(onPressed: () {}, label: 'Save')
   ```

2. **Replace form inputs:**
   ```dart
   // Old
   TextFormField(decoration: InputDecoration(label: Text('Name')))
   
   // New
   FormInput(label: 'Name', controller: _controller)
   ```

3. **Add empty states:**
   ```dart
   if (items.isEmpty) {
     return EmptyState(icon: Icons.inbox, title: 'No items');
   }
   ```

4. **Use dialog utilities:**
   ```dart
   // Instead of raw showDialog()
   await AppDialogs.showConfirm(context: context, ...)
   ```

## Responsive Design

Components automatically adapt to screen size:

- **Phone** (< 720px): Full-width buttons, single column layouts
- **Tablet** (≥ 720px): Side-by-side layouts, constrained widths

Use `isTablet(context)` and `TabletConstrain` for responsive layouts.

## Dark Mode Support

All components automatically adapt colors based on theme:

```dart
// Automatically light in light mode, dark in dark mode
Color get bg => ThemeService.isDark 
    ? const Color(0xFF0B1120) 
    : const Color(0xFFF8FAFC);
```

## Next Steps

1. Review existing screens and identify opportunities to use new components
2. Update form screens to use `FormInput` component
3. Add empty states to all list screens
4. Replace raw dialogs with `AppDialogs` utilities
5. Implement proper error handling with snackbars
