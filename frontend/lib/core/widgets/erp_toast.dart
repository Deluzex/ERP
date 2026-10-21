import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';

enum ToastType { success, error, warning, info }

/// Standard compact, top-right floating toast notification for Deluzex ERP.
/// Replaces oversized bottom snackbars with sleek, responsive toasts.
class ErpToast {
  ErpToast._();

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message: message, type: ToastType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Clear existing notifications to prevent duplicate stacking
    messenger.clearSnackBars();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 700;

    final (Color bgColor, Color borderColor, Color textColor, IconData icon) = switch (type) {
      ToastType.success => (
          const Color(0xFFF0FDF4), // Emerald green tint
          const Color(0xFF86EFAC),
          const Color(0xFF15803D),
          Icons.check_circle_rounded,
        ),
      ToastType.error => (
          const Color(0xFFFEF2F2),
          const Color(0xFFFCA5A5),
          const Color(0xFFB91C1C),
          Icons.error_rounded,
        ),
      ToastType.warning => (
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          const Color(0xFFB45309),
          Icons.warning_amber_rounded,
        ),
      ToastType.info => (
          const Color(0xFFEFF6FF),
          const Color(0xFFBFDBFE),
          const Color(0xFF1D4ED8),
          Icons.info_rounded,
        ),
    };

    // Calculate top-right floating bounds
    final bottomMargin = (size.height - 110).clamp(40.0, double.infinity);
    final leftMargin = isDesktop ? (size.width - 440).clamp(16.0, double.infinity) : 16.0;

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.only(
          bottom: bottomMargin,
          right: 20,
          left: leftMargin,
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.mdBorderRadius,
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => messenger.hideCurrentSnackBar(),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16, color: textColor.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
