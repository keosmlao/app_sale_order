import 'package:flutter/material.dart';
import '../app_theme.dart';

/// ─── Enhanced Button Components ──────────────────────────────────────────
/// Specialized button styles for different use cases. Provides consistent
/// interaction feedback, proper hit targets, and semantic meaning through
/// visual hierarchy.

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isDisabled = false,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final bool isFullWidth;
  final bool isDisabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label);

    final button = FilledButton(
      onPressed: (isLoading || isDisabled) ? null : onPressed,
      child: child,
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isFullWidth = true,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isFullWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          )
        : Text(label);

    final button = OutlinedButton(
      onPressed: onPressed,
      child: child,
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isFullWidth = false,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isFullWidth;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Text(label);

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
      child: child,
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// ─── Enhanced Form Input Component ──────────────────────────────────────
/// Wraps TextFormField with built-in label, hint, icon, and error styling.
/// Automatically handles focus states and provides consistent spacing.

class FormInput extends StatelessWidget {
  const FormInput({
    super.key,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
    this.errorText,
  });

  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final int maxLines;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
            errorText: errorText,
          ),
          maxLines: maxLines,
          minLines: maxLines == 1 ? 1 : null,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          obscureText: obscureText && maxLines == 1,
        ),
      ],
    );
  }
}

/// ─── Status Badge Component ──────────────────────────────────────────────
/// Compact badge for displaying status with appropriate color coding.
/// Supports both label-only and label-with-icon styles.

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.size = StatusBadgeSize.medium,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final (fontSize, padding, iconSize) = switch (size) {
      StatusBadgeSize.small => (11.0, const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 12.0),
      StatusBadgeSize.medium => (12.0, const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 14.0),
      StatusBadgeSize.large => (13.0, const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 16.0),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusBadgeSize { small, medium, large }

/// ─── Empty State Component ──────────────────────────────────────────────
/// Displays a friendly message when no data is available. Includes icon,
/// title, subtitle, and optional action button.

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace5, vertical: kSpace8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: kSpace5),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: kSpace2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: kSpace5),
              PrimaryButton(
                onPressed: onAction,
                label: actionLabel!,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ─── Error State Component ──────────────────────────────────────────────
/// Displays an error message with optional retry action and error details.

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.retryLabel = 'ລອງໃໝ່',
  });

  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace5, vertical: kSpace8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.danger.withValues(alpha: 0.3),
            ),
            const SizedBox(height: kSpace5),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: kSpace2),
              Text(
                details!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: kSpace5),
              PrimaryButton(
                onPressed: onRetry,
                label: retryLabel,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ─── Card Variants Component ────────────────────────────────────────────
/// Elevated, outlined, and filled card variants with consistent styling.

class ElevatedCard extends StatelessWidget {
  const ElevatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(kSpace4),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(kSpace4),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ─── Section Header Component ──────────────────────────────────────────
/// Styled section header for grouping content with icon and optional action.

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: kSpace2),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// ─── Info Banner Component ──────────────────────────────────────────────
/// Inline informational, warning, or success banner with icon and message.

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.type = BannerType.info,
    this.icon,
  });

  final String message;
  final BannerType type;
  final IconData? icon;

  Color get _backgroundColor => switch (type) {
    BannerType.info => AppColors.info.withValues(alpha: 0.1),
    BannerType.warning => AppColors.warning.withValues(alpha: 0.1),
    BannerType.success => AppColors.success.withValues(alpha: 0.1),
    BannerType.error => AppColors.danger.withValues(alpha: 0.1),
  };

  Color get _borderColor => switch (type) {
    BannerType.info => AppColors.info.withValues(alpha: 0.3),
    BannerType.warning => AppColors.warning.withValues(alpha: 0.3),
    BannerType.success => AppColors.success.withValues(alpha: 0.3),
    BannerType.error => AppColors.danger.withValues(alpha: 0.3),
  };

  Color get _textColor => switch (type) {
    BannerType.info => AppColors.info,
    BannerType.warning => AppColors.warning,
    BannerType.success => AppColors.success,
    BannerType.error => AppColors.danger,
  };

  IconData get _defaultIcon => switch (type) {
    BannerType.info => Icons.info_rounded,
    BannerType.warning => Icons.warning_rounded,
    BannerType.success => Icons.check_circle_rounded,
    BannerType.error => Icons.error_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border.all(color: _borderColor, width: 0.8),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        children: [
          Icon(icon ?? _defaultIcon, color: _textColor, size: 18),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerType { info, warning, success, error }

/// ─── Loading Overlay Component ──────────────────────────────────────────
/// Full-screen or widget-level loading indicator with optional message.

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: kSpace4),
                      Text(
                        message!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ─── Expandable List Tile Component ────────────────────────────────────
/// Enhanced ExpansionTile with better styling and animations.

class ExpandableListTile extends StatefulWidget {
  const ExpandableListTile({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final IconData? trailing;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<ExpandableListTile> createState() => _ExpandableListTileState();
}

class _ExpandableListTileState extends State<ExpandableListTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: kMotionMed,
      vsync: this,
      value: _isExpanded ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
          if (expanded) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
        },
        leading: widget.leading != null ? Icon(widget.leading) : null,
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: widget.subtitle != null
            ? Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              )
            : null,
        trailing: RotationTransition(
          turns: Tween<double>(begin: 0, end: 0.5).animate(_controller),
          child: Icon(
            widget.trailing ?? Icons.expand_more_rounded,
            color: AppColors.textMuted,
          ),
        ),
        children: widget.children,
      ),
    );
  }
}

/// ─── Divider with Text Component ────────────────────────────────────────
/// Decorative divider with centered text label.

class DividerWithText extends StatelessWidget {
  const DividerWithText({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.border, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace3),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.border, height: 1),
        ),
      ],
    );
  }
}

/// ─── Quantity Input Component ──────────────────────────────────────────
/// Spinbox for quantity input with + and - buttons.

class QuantityInput extends StatelessWidget {
  const QuantityInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove_rounded, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            iconSize: 18,
          ),
          SizedBox(
            width: 50,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            iconSize: 18,
          ),
        ],
      ),
    );
  }
}

/// ─── Chip Input Component ──────────────────────────────────────────────
/// Display list of items as removable chips for filtering or selection.

class ChipInput extends StatelessWidget {
  const ChipInput({
    super.key,
    required this.items,
    required this.onRemove,
  });

  final List<String> items;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace2,
      children: items
          .map(
            (item) => Chip(
              label: Text(item),
              onDeleted: () => onRemove(item),
              backgroundColor: AppColors.cardElev,
            ),
          )
          .toList(),
    );
  }
}
