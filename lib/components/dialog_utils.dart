import 'package:flutter/material.dart';
import '../app_theme.dart';

/// ─── Dialog Utilities ──────────────────────────────────────────────────────
/// Helper functions for showing consistent, well-designed dialogs throughout
/// the app. Follows Material 3 design principles with the app's color scheme.

class AppDialogs {
  /// Show a confirmation dialog with Yes/No options
  static Future<bool> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'ຕົກລົງ',
    String cancelLabel = 'ຍົກເລີກ',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDangerous ? AppColors.danger : AppColors.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show a single action dialog
  static Future<void> showAlert({
    required BuildContext context,
    required String title,
    required String message,
    String buttonLabel = 'ຕົກລົງ',
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  /// Show input dialog
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    String? hint,
    String submitLabel = 'ບັນທຶກ',
    String cancelLabel = 'ຍົກເລີກ',
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(submitLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

/// ─── Bottom Sheet Utilities ────────────────────────────────────────────────
/// Helper functions for showing bottom sheets with consistent styling.

class AppBottomSheets {
  /// Show a simple menu bottom sheet
  static Future<T?> showMenu<T>({
    required BuildContext context,
    required String title,
    required List<({String label, IconData? icon, T value})> items,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      builder: (context) => _MenuBottomSheet(
        title: title,
        items: items,
      ),
    );
  }

  /// Show a custom content bottom sheet
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    bool isScrollable = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollable,
      builder: (context) => _CustomBottomSheet(
        title: title,
        child: child,
      ),
    );
  }
}

class _MenuBottomSheet<T> extends StatelessWidget {
  const _MenuBottomSheet({
    required this.title,
    required this.items,
  });

  final String title;
  final List<({String label, IconData? icon, T value})> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: item.icon != null ? Icon(item.icon) : null,
              title: Text(item.label),
              onTap: () => Navigator.pop(context, item.value),
            );
          },
        ),
      ],
    );
  }
}

class _CustomBottomSheet extends StatelessWidget {
  const _CustomBottomSheet({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kSpace4),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// ─── Snackbar Utilities ────────────────────────────────────────────────────
/// Helper functions for showing snackbars with different message types.

class AppSnackBars {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: kSpace3),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: kSpace3),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.white),
            const SizedBox(width: kSpace3),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_rounded, color: Colors.white),
            const SizedBox(width: kSpace3),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.info,
      ),
    );
  }
}

/// ─── Data Table Component ──────────────────────────────────────────────────
/// Simple data table for displaying tabular data with consistent styling.

class SimpleDataTable extends StatelessWidget {
  const SimpleDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnWidths,
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final Map<int, double>? columnWidths;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map(
              (col) => DataColumn(
                label: Text(
                  col,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: row
                    .map((cell) => DataCell(cell))
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// ─── Progress Step Component ──────────────────────────────────────────────
/// Visual stepper for multi-step processes.

class ProgressStep extends StatelessWidget {
  const ProgressStep({
    super.key,
    required this.steps,
    required this.currentStep,
  });

  final List<String> steps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: i <= currentStep
                            ? AppColors.primary
                            : AppColors.cardElev,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (i + 1).toString(),
                        style: TextStyle(
                          color: i <= currentStep
                              ? Colors.white
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpace2),
                    if (i < steps.length)
                      Text(
                        steps[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: i <= currentStep
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: i <= currentStep
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentStep
                        ? AppColors.primary
                        : AppColors.border,
                    margin: const EdgeInsets.symmetric(vertical: 19),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

/// ─── Tab Navigation Component ──────────────────────────────────────────────
/// Custom tab bar with smooth animations and underline indicator.

class CustomTabBar extends StatefulWidget {
  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.onChanged,
    this.initialIndex = 0,
  });

  final List<String> tabs;
  final ValueChanged<int> onChanged;
  final int initialIndex;

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _controller.addListener(() {
      widget.onChanged(_controller.index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: _controller,
      tabs: widget.tabs.map((tab) => Tab(text: tab)).toList(),
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorWeight: 3,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );
  }
}

/// ─── Animated Counter Component ─────────────────────────────────────────
/// Animated number counter for displaying statistics and metrics.

class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.label,
    this.duration = const Duration(milliseconds: 800),
    this.formatter,
  });

  final num value;
  final String label;
  final Duration duration;
  final String Function(num)? formatter;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<num> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _setupAnimation();
    _controller.forward();
  }

  void _setupAnimation() {
    _animation = Tween<num>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.reset();
      _setupAnimation();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final formatted = widget.formatter?.call(_animation.value) ??
                _animation.value.toStringAsFixed(0);
            return Text(
              formatted,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            );
          },
        ),
        const SizedBox(height: kSpace2),
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// ─── Search Bar Component ──────────────────────────────────────────────────
/// Beautiful search input with icon and optional filter button.

class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    this.placeholder = 'ຊອກຫາ...',
    required this.onChanged,
    this.onFilterTap,
    this.controller,
  });

  final String placeholder;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final TextEditingController? controller;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace3),
            child: Icon(Icons.search_rounded, color: AppColors.textMuted),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (widget.onFilterTap != null)
            IconButton(
              icon: Icon(Icons.tune_rounded),
              onPressed: widget.onFilterTap,
            ),
        ],
      ),
    );
  }
}
