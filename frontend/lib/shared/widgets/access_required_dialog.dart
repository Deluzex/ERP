import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/models/rbac_models.dart';
import '../../core/widgets/erp_button.dart';
import '../providers/app_state_providers.dart';

class AccessRequiredDialog extends ConsumerStatefulWidget {
  final ErpModule module;
  final ErpAction? action;
  final String? customTitle;
  final String? customMessage;
  final void Function(TemporaryAccessGrant grant)? onAccessGranted;

  const AccessRequiredDialog({
    super.key,
    required this.module,
    this.action,
    this.customTitle,
    this.customMessage,
    this.onAccessGranted,
  });

  static Future<bool> show(
    BuildContext context, {
    required ErpModule module,
    ErpAction? action,
    String? customTitle,
    String? customMessage,
    void Function(TemporaryAccessGrant grant)? onAccessGranted,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AccessRequiredDialog(
        module: module,
        action: action,
        customTitle: customTitle,
        customMessage: customMessage,
        onAccessGranted: onAccessGranted,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AccessRequiredDialog> createState() => _AccessRequiredDialogState();
}

class _AccessRequiredDialogState extends ConsumerState<AccessRequiredDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedDurationMinutes = 30;
  bool _isSessionOnly = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _verifyAccess() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an authorized password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final db = ref.read(databaseServiceProvider);
    final currentUser = ref.read(currentUserProvider) ?? db.currentUser;

    final result = db.verifySupervisorPasswordAndGrantAccess(
      currentUser: currentUser,
      password: password,
      targetModule: widget.module,
      targetAction: widget.action,
      durationMinutes: _selectedDurationMinutes,
      isSessionOnly: _isSessionOnly,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.success && result.grant != null) {
      if (widget.onAccessGranted != null) {
        widget.onAccessGranted!(result.grant!);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Access granted by ${result.authorizerName}. Temporary override is active.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final moduleName = widget.module.label.toUpperCase();
    final actionName = widget.action?.label ?? 'Access';

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 480;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      backgroundColor: AppColors.surface,
      elevation: 24,
      insetPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 40, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        width: double.infinity,
        padding: EdgeInsets.all(isCompact ? 18 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Security Lock Icon & Module Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_person_rounded, size: 28, color: Colors.amber.shade800),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customTitle ?? '🔒 Access Required',
                        style: AppTextStyles.h2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Permission Restricted • ', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              moduleName,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message text
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.mdBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customMessage ??
                        'You do not have permission to $actionName the "$moduleName" module under your current role.',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please enter an authorized supervisor or administrator password to unlock temporary access.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Authorized Password Input
            Text('Authorized Password *', style: AppTextStyles.bodyBold),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              onSubmitted: (_) => _verifyAccess(),
              decoration: InputDecoration(
                hintText: 'Enter Supervisor / Admin Password',
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 16),

            // Temporary Access Policy Duration Selector
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temporary Access Duration', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _isSessionOnly ? -1 : _selectedDurationMinutes,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 Minutes', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 30, child: Text('30 Minutes (Standard)', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 60, child: Text('1 Hour (Extended)', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: -1, child: Text('Current Session Only', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            if (val == -1) {
                              _isSessionOnly = true;
                              _selectedDurationMinutes = 0;
                            } else {
                              _isSessionOnly = false;
                              _selectedDurationMinutes = val;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 10,
              children: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                ),
                ErpButton(
                  text: _isLoading ? 'Verifying...' : 'Verify Access',
                  icon: Icons.lock_open_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _verifyAccess,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
