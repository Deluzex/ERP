import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/rbac_models.dart';
import '../../shared/providers/app_state_providers.dart';
import '../../shared/widgets/access_required_dialog.dart';

/// Helper to execute an action with RBAC checks and supervisor challenge if restricted
Future<void> runGuardedAction(
  BuildContext context,
  WidgetRef ref, {
  required ErpModule module,
  required ErpAction action,
  String? customActionTitle,
  String? customMessage,
  required VoidCallback onGranted,
}) async {
  final db = ref.read(databaseServiceProvider);
  final currentUser = ref.read(currentUserProvider) ?? db.currentUser;
  final allRoles = db.roles;
  final temporaryGrants = db.temporaryGrants;

  final hasAccess = currentUser.hasPermission(module, action, allRoles, temporaryGrants);

  if (hasAccess) {
    onGranted();
  } else {
    final granted = await AccessRequiredDialog.show(
      context,
      module: module,
      action: action,
      customTitle: customActionTitle ?? '🔒 Authorization Required for ${action.label}',
      customMessage: customMessage ??
          'You need authorized access to ${action.label.toLowerCase()} in the "${module.label}" module.',
      onAccessGranted: (_) {
        onGranted();
      },
    );

    if (granted) {
      // already called onAccessGranted
    }
  }
}
