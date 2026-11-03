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
    this.narrowBreakpoint = 480,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 520;
        final isSmallMobile = constraints.maxWidth < 380;

        // Adaptive breakpoint for intermediate screens between mobile and full desktop.
        // 4 buttons take ~750px and require at least ~1220px card width to sit comfortably side-by-side with title.
        // 3 buttons take ~480px and require at least ~1000px card width.
        // 2 buttons take ~320px and require at least ~800px card width.
        final actionCount = actions?.length ?? (action != null ? 4 : 0);
        final defaultBreakpoint = actionCount >= 4
            ? 1220.0
            : (actionCount == 3
                ? 1000.0
                : (actionCount == 2
                    ? 800.0
                    : (actionCount == 1 ? 580.0 : 480.0)));
        final effectiveBreakpoint = narrowBreakpoint != 480 ? narrowBreakpoint : defaultBreakpoint;
        final isDesktop = constraints.maxWidth >= effectiveBreakpoint;
        final isIntermediate = !isDesktop && !isMobile;

        Widget? effectiveAction = action;
        if (actions != null && actions!.isNotEmpty) {
          if (isMobile) {
            // Mobile: keep existing full-width vertical stack
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
          } else if (isIntermediate) {
            // Between mobile & desktop: wrap buttons horizontally under the title
            effectiveAction = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions!,
            );
          } else {
            // Desktop: keep existing end-aligned side-by-side wrap
            effectiveAction = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions!,
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
          child: isDesktop
              ? Row(
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
                )
              : Column(
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
                      SizedBox(height: isMobile ? 12 : 14),
                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: effectiveAction,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
