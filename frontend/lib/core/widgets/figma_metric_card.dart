import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class FigmaMetricCard extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final String title;
  final String value;
  final String subtext;
  final Color? subtextColor;
  final double titleValueSpacing;
  final double valueSubtextSpacing;

  const FigmaMetricCard({
    super.key,
    this.icon,
    this.iconWidget,
    this.iconColor = AppColors.primary,
    required this.title,
    required this.value,
    required this.subtext,
    this.subtextColor,
    this.titleValueSpacing = 6,
    this.valueSubtextSpacing = 4,
  }) : assert(icon != null || iconWidget != null, 'Either icon or iconWidget must be provided');

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E6EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (iconWidget != null)
                iconWidget!
              else if (icon != null)
                Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: titleValueSpacing),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.metricValue.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
                height: 1.15,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: valueSubtextSpacing),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: subtextColor ?? const Color(0xFF737686),
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
