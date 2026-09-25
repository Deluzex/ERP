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
        width: 480,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ErpButton(
                    text: 'Cancel',
                    isOutlined: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
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
