import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// =========================================================
/// FUNCTION VERSION (USED IN MANY PLACES)
/// =========================================================
void showSuccessDialog(
  BuildContext context,
  String title,
  String message,
  VoidCallback onOk,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => SuccessDialog(title: title, message: message, onOk: onOk),
  );
}

/// =========================================================
/// WIDGET VERSION (REUSABLE)
/// =========================================================
class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onOk;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// ✅ SUCCESS ICON
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: cs.primary,
                  size: 36,
                ),
              ),

              const SizedBox(height: 16),

              /// ✅ TITLE
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),

              const SizedBox(height: 8),

              /// ✅ MESSAGE
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),

              const SizedBox(height: 24),

              /// ✅ ACTION BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onOk?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
