import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';

class ErpButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isDanger;
  final bool isOutlined;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;

  const ErpButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.isDanger = false,
    this.isOutlined = false,
    this.isLoading = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDanger ? AppColors.danger : AppColors.border,
            width: 1.2,
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
          foregroundColor: isDanger ? AppColors.danger : AppColors.textPrimary,
        ),
        child: _buildChild(isDanger ? AppColors.danger : AppColors.textPrimary),
      );
    }

    Color bgColor;
    Color fgColor = Colors.white;

    if (isDanger) {
      bgColor = AppColors.danger;
    } else if (isPrimary) {
      bgColor = AppColors.primary;
    } else {
      bgColor = AppColors.sidebarBackground;
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
      ),
      child: _buildChild(fgColor),
    );
  }

  Widget _buildChild(Color fgColor) {
    if (isLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }

    if (icon != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 8),
            Text(
              text,
              style: AppTextStyles.button.copyWith(color: fgColor),
              maxLines: 1,
            ),
          ],
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: AppTextStyles.button.copyWith(color: fgColor),
        maxLines: 1,
      ),
    );
  }
}
