import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'erp_button.dart';

class ErpConfirmDeleteDialog extends StatefulWidget {
  final String title;
  final String message;
  final String itemName;
  final bool requireReason;
  final Function(String reason) onConfirm;

  const ErpConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.itemName,
    this.requireReason = true,
    required this.onConfirm,
  });

  @override
  State<ErpConfirmDeleteDialog> createState() => _ErpConfirmDeleteDialogState();
}

class _ErpConfirmDeleteDialogState extends State<ErpConfirmDeleteDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        width: double.infinity,
        padding: AppSpacing.dialogPadding,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.dangerText,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.h3.copyWith(color: AppColors.dangerText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.smBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  widget.itemName,
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                ),
              ),
              if (widget.requireReason) ...[
                const SizedBox(height: 16),
                Text(
                  'Reason for deletion (Mandatory)',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a mandatory reason for deletion';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'E.g., Vendor business closed / Contract terminated',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 10,
                children: [
                  ErpButton(
                    text: 'Cancel',
                    isOutlined: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  ErpButton(
                    text: 'Confirm Delete',
                    isDanger: true,
                    onPressed: () {
                      if (widget.requireReason && !_formKey.currentState!.validate()) {
                        return;
                      }
                      widget.onConfirm(_reasonController.text.trim());
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact, professionally-designed modal dialog for Deactivate / Activate confirmation
class ErpStatusConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? itemName;
  final bool willActivate;
  final String confirmLabel;
  final FutureOr<void> Function() onConfirm;
  final VoidCallback? onCancel;

  const ErpStatusConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.itemName,
    required this.willActivate,
    required this.confirmLabel,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      backgroundColor: Colors.white,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480, // Compact 450–550px fixed max width on desktop
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: willActivate
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: willActivate
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Icon(
                      willActivate ? Icons.play_circle_outline : Icons.pause_circle_outline,
                      color: willActivate ? AppColors.success : AppColors.warning,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              if (itemName != null && itemName!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.smBorderRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    itemName!,
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCancel?.call();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      backgroundColor: willActivate ? AppColors.success : AppColors.warning,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await onConfirm();
                    },
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showErpStatusConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? itemName,
  required bool willActivate,
  required String confirmLabel,
  required FutureOr<void> Function() onConfirm,
  VoidCallback? onCancel,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ErpStatusConfirmDialog(
      title: title,
      message: message,
      itemName: itemName,
      willActivate: willActivate,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
      onCancel: onCancel,
    ),
  );
}
