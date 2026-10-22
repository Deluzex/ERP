import 'package:flutter/material.dart';

class ErpStatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final FontWeight fontWeight;

  const ErpStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.borderRadius = 6.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.fontSize = 11.0,
    this.fontWeight = FontWeight.w700,
  });

  /// Success / Paid / Accepted / Completed / Active (Soft Mint Green)
  factory ErpStatusBadge.success(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFECFDF5),
      borderColor: const Color(0xFFA7F3D0),
      textColor: const Color(0xFF047857),
    );
  }

  /// Danger / Cancelled / Rejected / Inactive (Soft Crimson Red)
  factory ErpStatusBadge.danger(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFFEF2F2),
      borderColor: const Color(0xFFFECACA),
      textColor: const Color(0xFFB91C1C),
    );
  }

  /// Warning / Partial / Waiting Approval / Production / Pending Review (Soft Cream Amber)
  factory ErpStatusBadge.warning(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFFDE68A),
      textColor: const Color(0xFFB45309),
    );
  }

  /// Info / Saved / In Progress / Dispatched / Issued (Soft Indigo Blue)
  factory ErpStatusBadge.info(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFEEF2FF),
      borderColor: const Color(0xFFC7D2FE),
      textColor: const Color(0xFF4338CA),
    );
  }

  /// Neutral / Draft / Closed / Delivered / Confirmed (Soft Slate Grey)
  factory ErpStatusBadge.neutral(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFF1F5F9),
      borderColor: const Color(0xFFCBD5E1),
      textColor: const Color(0xFF475569),
    );
  }

  /// Category Purple / Submitted (Soft Lavender)
  factory ErpStatusBadge.categoryPurple(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFF5F3FF),
      borderColor: const Color(0xFFDDD6FE),
      textColor: const Color(0xFF6D28D9),
    );
  }

  /// Category Blue (Soft Sky Blue)
  factory ErpStatusBadge.categoryBlue(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFEFF6FF),
      borderColor: const Color(0xFFBFDBFE),
      textColor: const Color(0xFF1D4ED8),
    );
  }

  /// Category Orange (Soft Warm Orange)
  factory ErpStatusBadge.categoryOrange(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFFFF7ED),
      borderColor: const Color(0xFFFED7AA),
      textColor: const Color(0xFFC2410C),
    );
  }

  /// Category Teal (Soft Teal Cyan)
  factory ErpStatusBadge.categoryTeal(String label) {
    return ErpStatusBadge(
      label: label,
      backgroundColor: const Color(0xFFF0FDFA),
      borderColor: const Color(0xFF99F6E4),
      textColor: const Color(0xFF0F766E),
    );
  }

  /// Category Green
  factory ErpStatusBadge.categoryGreen(String label) => ErpStatusBadge.success(label);

  /// Category Neutral
  factory ErpStatusBadge.categoryNeutral(String label) => ErpStatusBadge.neutral(label);

  // Backward-compatible & convenience aliases matching the design system
  factory ErpStatusBadge.purple(String label) => ErpStatusBadge.categoryPurple(label);
  factory ErpStatusBadge.teal(String label) => ErpStatusBadge.categoryTeal(label);
  factory ErpStatusBadge.saved(String label) => ErpStatusBadge.info(label);
  factory ErpStatusBadge.paid(String label) => ErpStatusBadge.success(label);
  factory ErpStatusBadge.partial(String label) => ErpStatusBadge.warning(label);
  factory ErpStatusBadge.draft(String label) => ErpStatusBadge.neutral(label);
  factory ErpStatusBadge.cancelled(String label) => ErpStatusBadge.danger(label);

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? textColor.withValues(alpha: 0.35);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorderColor, width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
