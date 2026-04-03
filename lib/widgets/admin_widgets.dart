import 'package:flutter/material.dart';
import '../utils/admin_design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN WIDGETS LIBRARY
// Reusable premium widgets for the SmartStay Admin Module
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────
// 1. Admin Page Header
// ─────────────────────────────────────────────
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final LinearGradient? iconGradient;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconGradient,
    this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        boxShadow: AdminShadows.header,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _BackButton(onTap: onBack!),
            const SizedBox(width: 12),
          ],
          _IconBadge(icon: icon, gradient: iconGradient ?? AdminGradients.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminColors.textMuted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252836) : const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(10),
          border: isDark ? Border.all(color: const Color(0xFF2E3347)) : null,
        ),
        child: const Icon(Icons.arrow_back_ios_new, size: 16),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final LinearGradient gradient;
  const _IconBadge({required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

// ─────────────────────────────────────────────
// 2. Stat Card
// ─────────────────────────────────────────────
class AdminStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String? subtitle;
  final Color? subtitleColor;

  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  State<AdminStatCard> createState() => _AdminStatCardState();
}

class _AdminStatCardState extends State<AdminStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          borderRadius: AdminRadius.lg,
          border: isDark
              ? Border.all(color: const Color(0xFF2E3347))
              : Border.all(color: const Color(0xFFF0F0F5)),
          boxShadow: AdminShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 20),
                ),
                Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: AdminColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 12,
                color: AdminColors.textSecondary,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.subtitleColor ?? AdminColors.textMuted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 3. Section Card (gradient header + white body)
// ─────────────────────────────────────────────
class AdminSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final LinearGradient headerGradient;
  final Color iconColor;
  final Widget child;
  final EdgeInsets? bodyPadding;

  const AdminSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.headerGradient,
    required this.iconColor,
    required this.child,
    this.bodyPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: AdminRadius.lg,
        boxShadow: AdminShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: bodyPadding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 4. Admin Text Field
// ─────────────────────────────────────────────
class AdminTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final String? initialValue;

  const AdminTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixWidget,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.obscureText = false,
    this.focusNode,
    this.textInputAction,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: isDark
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          obscureText: obscureText,
          focusNode: focusNode,
          textInputAction: textInputAction,
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Inter',
            color: isDark ? Colors.white : AdminColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AdminColors.textMuted,
              fontFamily: 'Inter',
              fontSize: 14,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AdminColors.textMuted, size: 18)
                : null,
            suffix: suffixWidget,
            filled: true,
            fillColor: isDark ? const Color(0xFF252836) : const Color(0xFFF8F9FC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AdminColors.primary,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminColors.danger, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 5. Primary Button with loading state
// ─────────────────────────────────────────────
class AdminPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final LinearGradient? gradient;
  final double height;
  final double? width;

  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient,
    this.height = 52,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? AdminGradients.primary;
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null ? grad : null,
          color: onPressed == null ? AdminColors.textMuted : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: grad.colors.first.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: EdgeInsets.zero,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 6. Shimmer Box (no external package)
// ─────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF252836) : const Color(0xFFEEEEEE);
    final highlightColor =
        isDark ? const Color(0xFF2E3347) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}

class ShimmerStatCardGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;

  const ShimmerStatCardGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: List.generate(
        count,
        (_) => const ShimmerBox(width: double.infinity, height: 120),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 7. Empty State
// ─────────────────────────────────────────────
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AdminColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AdminColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: AdminColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminColors.textSecondary,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 8. Success Dialog
// ─────────────────────────────────────────────
Future<void> showAdminSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'Done',
  VoidCallback? onDismiss,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AdminSuccessDialog(
      title: title,
      message: message,
      buttonLabel: buttonLabel,
      onDismiss: onDismiss,
    ),
  );
}

class _AdminSuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback? onDismiss;

  const _AdminSuccessDialog({
    required this.title,
    required this.message,
    required this.buttonLabel,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E2130)
              : Colors.white,
          borderRadius: AdminRadius.xl,
          boxShadow: AdminShadows.cardHover,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AdminColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AdminColors.success,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                color: AdminColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AdminColors.textSecondary,
                fontFamily: 'Inter',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDismiss?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 9. Confirm Dialog
// ─────────────────────────────────────────────
Future<bool> showAdminConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDangerous = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _AdminConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDangerous: isDangerous,
    ),
  );
  return result ?? false;
}

class _AdminConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDangerous;

  const _AdminConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDangerous,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor = isDangerous ? AdminColors.danger : AdminColors.primary;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E2130)
              : Colors.white,
          borderRadius: AdminRadius.xl,
          boxShadow: AdminShadows.cardHover,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDangerous
                    ? AdminColors.dangerLight
                    : AdminColors.infoLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDangerous
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                color: isDangerous ? AdminColors.danger : AdminColors.info,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                color: AdminColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AdminColors.textSecondary,
                fontFamily: 'Inter',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AdminColors.cardBorder),
                    ),
                    child: Text(cancelLabel,
                        style: const TextStyle(fontFamily: 'Inter')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(
                            fontFamily: 'Inter', fontWeight: FontWeight.w600)),
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

// ─────────────────────────────────────────────
// 10. Bed Grid Widget
// ─────────────────────────────────────────────
class BedGrid extends StatelessWidget {
  final int totalBeds;
  final Set<String> occupiedBedIds; // e.g., {'B1', 'B3'}
  final String? selectedBedId;
  final ValueChanged<String>? onBedTap;

  const BedGrid({
    super.key,
    required this.totalBeds,
    required this.occupiedBedIds,
    this.selectedBedId,
    this.onBedTap,
  });

  @override
  Widget build(BuildContext context) {
    if (totalBeds <= 0) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(totalBeds, (i) {
        final bedId = 'B${i + 1}';
        final isOccupied = occupiedBedIds.contains(bedId);
        final isSelected = selectedBedId == bedId;

        Color bgColor;
        Color borderColor;
        Color textColor;
        if (isSelected) {
          bgColor = AdminColors.primary;
          borderColor = AdminColors.primary;
          textColor = Colors.white;
        } else if (isOccupied) {
          bgColor = AdminColors.dangerLight;
          borderColor = AdminColors.danger;
          textColor = AdminColors.danger;
        } else {
          bgColor = AdminColors.successLight;
          borderColor = AdminColors.success;
          textColor = AdminColors.success;
        }

        return GestureDetector(
          onTap: isOccupied ? null : () => onBedTap?.call(bedId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOccupied ? Icons.person : Icons.bed,
                  size: 20,
                  color: textColor,
                ),
                const SizedBox(height: 2),
                Text(
                  bedId,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// 11. Status Badge
// ─────────────────────────────────────────────
class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const AdminBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: textColor ?? color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 12. Section Title
// ─────────────────────────────────────────────
class AdminSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const AdminSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            color: AdminColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: AdminColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 13. Info Banner (for notices / tips inside forms)
// ─────────────────────────────────────────────
class AdminInfoBanner extends StatelessWidget {
  final String message;
  final Color? color;
  final IconData icon;

  const AdminInfoBanner({
    super.key,
    required this.message,
    this.color,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AdminColors.info;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: c.withOpacity(0.9),
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 14. Occupancy Progress Bar
// ─────────────────────────────────────────────
class OccupancyBar extends StatelessWidget {
  final String label;
  final int occupied;
  final int total;
  final Color? barColor;

  const OccupancyBar({
    super.key,
    required this.label,
    required this.occupied,
    required this.total,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (occupied / total).clamp(0.0, 1.0);
    final pctLabel = '${(pct * 100).toInt()}%';
    final color = barColor ??
        (pct >= 0.9
            ? AdminColors.danger
            : pct >= 0.6
                ? AdminColors.warning
                : AdminColors.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                  color: AdminColors.textSecondary,
                ),
              ),
            ),
            Text(
              '$occupied/$total  ($pctLabel)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 14. Scrollable Card Content
// ─────────────────────────────────────────────
/// Wraps child content in a max-height scrollable area with a
/// bottom fade gradient that hints at more content below.
/// The fade hides automatically when content doesn't overflow
/// or when the user scrolls to the bottom.
class ScrollableCardContent extends StatefulWidget {
  final Widget child;
  final double maxHeight;

  const ScrollableCardContent({
    super.key,
    required this.child,
    this.maxHeight = 280,
  });

  @override
  State<ScrollableCardContent> createState() => _ScrollableCardContentState();
}

class _ScrollableCardContentState extends State<ScrollableCardContent> {
  final ScrollController _controller = ScrollController();
  bool _showFade = false;
  bool _hasCheckedOverflow = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(covariant ScrollableCardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check overflow when child content changes
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!_controller.hasClients || !mounted) return;
    final isOverflowing = _controller.position.maxScrollExtent > 0;
    final atBottom = _controller.position.pixels >=
        _controller.position.maxScrollExtent - 10;
    final shouldShowFade = isOverflowing && !atBottom;
    if (shouldShowFade != _showFade) {
      setState(() => _showFade = shouldShowFade);
    }
    _hasCheckedOverflow = true;
  }

  void _onScroll() {
    if (!_controller.hasClients || !mounted) return;
    final atBottom = _controller.position.pixels >=
        _controller.position.maxScrollExtent - 10;
    final isOverflowing = _controller.position.maxScrollExtent > 0;
    final shouldShowFade = isOverflowing && !atBottom;
    if (shouldShowFade != _showFade) {
      setState(() => _showFade = shouldShowFade);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AdminColors.card(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            child: widget.child,
          ),
          // Bottom fade gradient
          if (_showFade)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 48,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cardColor.withOpacity(0.0),
                        cardColor.withOpacity(0.85),
                        cardColor,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
