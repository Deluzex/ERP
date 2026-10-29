import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class ErpSectionHeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badgeText;
  final String? subtitle;
  final Widget? action;
  final List<Widget>? actions;
  final double narrowBreakpoint;

  const ErpSectionHeaderCard({
    super.key,
    required this.icon,
    required this.title,
    this.badgeText,
    this.subtitle,
    this.action,
    this.actions,
    this.narrowBreakpoint = 750,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < narrowBreakpoint;
        final isMobile = constraints.maxWidth < 520;
        final isSmallMobile = constraints.maxWidth < 380;

        Widget? effectiveAction = action;
        if (actions != null && actions!.isNotEmpty) {
          if (isNarrow) {
            effectiveAction = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions!.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: actions![i],
                  ),
                ],
              ],
            );
          } else {
            effectiveAction = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions!,
            );
          }
        } else if (effectiveAction is Row) {
          final rowChildren = effectiveAction.children.where((w) => w is! SizedBox).toList();
          if (isNarrow) {
            effectiveAction = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < rowChildren.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: rowChildren[i],
                  ),
                ],
              ],
            );
          } else {
            effectiveAction = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: rowChildren,
            );
          }
        }

        final badgeWidget = (badgeText != null && badgeText!.isNotEmpty)
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 7 : 9,
                  vertical: isMobile ? 2.5 : 3.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile ? 9.5 : 10.5,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : null;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h1.copyWith(
                    fontSize: isSmallMobile ? 15 : (isMobile ? 16.5 : 20),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                ?badgeWidget,
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        );

        final iconBox = Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: isMobile ? 24 : 28,
          ),
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 22,
            vertical: isMobile ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: iconBox,
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(child: titleBlock),
                      ],
                    ),
                    if (effectiveAction != null) ...[
                      SizedBox(height: isMobile ? 12 : 16),
                      SizedBox(
                        width: double.infinity,
                        child: effectiveAction,
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconBox,
                    const SizedBox(width: 16),
                    Expanded(child: titleBlock),
                    if (effectiveAction != null) ...[
                      const SizedBox(width: 16),
                      effectiveAction,
                    ],
                  ],
                ),
        );
      },
    );
  }
}
