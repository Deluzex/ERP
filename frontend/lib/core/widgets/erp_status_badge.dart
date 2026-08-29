import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';

class ErpStatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const ErpStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  factory ErpStatusBadge.success(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: AppColors.successLight,
      textColor: AppColors.successText,
    );
  }

  factory ErpStatusBadge.danger(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: AppColors.dangerLight,
      textColor: AppColors.dangerText,
    );
  }

  factory ErpStatusBadge.warning(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: AppColors.warningLight,
      textColor: AppColors.warningText,
    );
  }

  factory ErpStatusBadge.info(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: AppColors.infoLight,
      textColor: AppColors.infoText,
    );
  }

  factory ErpStatusBadge.neutral(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: AppColors.surfaceMuted,
      textColor: AppColors.textSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.pillBorderRadius,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
