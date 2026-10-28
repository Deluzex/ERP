import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class FigmaMetricCard extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final String title;
  final String value;
  final String subtext;
  final Color? subtextColor;

  const FigmaMetricCard({
    super.key,
    this.icon,
    this.iconWidget,
    this.iconColor = AppColors.primary,
    required this.title,
    required this.value,
    required this.subtext,
    this.subtextColor,
  }) : assert(icon != null || iconWidget != null, 'Either icon or iconWidget must be provided');

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: subtextColor ?? const Color(0xFF737686),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

