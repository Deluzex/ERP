import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import 'erp_button.dart';

/// Reusable ERP Empty State & Error State Widget
/// Displays a clean, professional banner when a table or collection has zero records
/// or when an API error occurs, providing an optional action or retry button.
class ErpEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final double verticalPadding;

  const ErpEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.errorMessage,
    this.onRetry,
    this.verticalPadding = 48.0,
  });

  /// Factory constructor for API error state with Retry action
  factory ErpEmptyState.error({
    Key? key,
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    return ErpEmptyState(
      key: key,
      icon: Icons.error_outline_rounded,
      title: title,
      subtitle: message,
      errorMessage: message,
      actionLabel: 'Retry Connection',
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isError = errorMessage != null && errorMessage!.isNotEmpty;

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 24.0),
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isError ? AppColors.dangerLight : AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: isError ? AppColors.dangerText : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: isError ? AppColors.dangerText : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isError ? AppColors.dangerText : AppColors.textMuted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              isError
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.smBorderRadius),
                      ),
                      icon: Icon(actionIcon ?? Icons.refresh, size: 18, color: AppColors.danger),
                      label: Text(
                        actionLabel!,
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                      onPressed: onAction,
                    )
                  : ErpButton(
                      text: actionLabel!,
                      icon: actionIcon ?? Icons.add,
                      onPressed: onAction!,
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

