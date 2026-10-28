import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/utils/document_sharing_service.dart';
import '../../../shared/providers/app_state_providers.dart';

enum MessageAudience { everyone, department, individual }

class BroadcastUser {
  final String id;
  final String name;
  final String department;
  final String phone;
  final String initials;
  final Color avatarColor;

  const BroadcastUser({
    required this.id,
    required this.name,
    required this.department,
    required this.phone,
    required this.initials,
    required this.avatarColor,
  });
}

class ChatSupportScreen extends ConsumerStatefulWidget {
  const ChatSupportScreen({super.key});

  @override
  ConsumerState<ChatSupportScreen> createState() => _ChatSupportScreenState();
}

class _ChatSupportScreenState extends ConsumerState<ChatSupportScreen> {
  final _subjectController = TextEditingController(
    text: 'Stock Update Reminder',
  );
  final _messageController = TextEditingController(
    text:
        'Please update today’s physical stock before 6:00 PM.\n'
        'Kindly ensure all items are counted and updated in the system.\n\n'
        'If you face any issue, please contact the admin.',
  );
  final _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};

  MessageAudience _audience = MessageAudience.everyone;
  String? _department;
  bool _whatsAppEnabled = true;
  bool _inAppEnabled = true;
  bool _initializedUsers = false;

  static String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  static Color _getAvatarColor(String? roleId) {
    switch (roleId) {
      case 'admin':
        return const Color(0xFF34577C);
      case 'inventory_manager':
        return const Color(0xFFAE8956);
      case 'purchase_manager':
        return const Color(0xFF7188A5);
      case 'production_manager':
        return const Color(0xFF4C9B7A);
      case 'sales_manager':
        return const Color(0xFFC94858);
      case 'accounts_manager':
        return const Color(0xFF6596C5);
      case 'project_manager':
        return const Color(0xFF735C9B);
      case 'masters_manager':
        return const Color(0xFF735C83);
      case 'report_viewer':
        return const Color(0xFFC16F8B);
      default:
        return const Color(0xFF5A738E);
    }
  }

  List<BroadcastUser> _getSystemBroadcastUsers() {
    final db = ref.watch(databaseServiceProvider);
    final allRoles = {for (final r in db.roles) r.id: r.name};

    return db.users.map((u) {
      final roleName = allRoles[u.primaryRoleId] ?? u.primaryRoleId;
      return BroadcastUser(
        id: u.id,
        name: u.name,
        department: roleName,
        phone: u.mobile,
        initials: _getInitials(u.name),
        avatarColor: _getAvatarColor(u.primaryRoleId),
      );
    }).toList();
  }

  List<BroadcastUser> _getFilteredUsers(List<BroadcastUser> users) {
    final query = _searchController.text.trim().toLowerCase();
    return users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          user.department.toLowerCase().contains(query) ||
          user.phone.toLowerCase().contains(query);
    }).toList();
  }

  List<BroadcastUser> _getSelectedUsers(List<BroadcastUser> users) {
    return users.where((user) => _selectedUserIds.contains(user.id)).toList();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _ensureInitialSelection(List<BroadcastUser> users) {
    if (!_initializedUsers && users.isNotEmpty) {
      _selectedUserIds.addAll(users.map((u) => u.id));
      final departments = users.map((u) => u.department).toSet().toList()..sort();
      if (departments.isNotEmpty) {
        _department = departments.first;
      }
      _initializedUsers = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemUsers = _getSystemBroadcastUsers();
    _ensureInitialSelection(systemUsers);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 960) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildComposerCard(systemUsers),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 340,
                      child: _buildSelectedUsersCard(systemUsers),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildComposerCard(systemUsers),
                  const SizedBox(height: AppSpacing.md),
                  _buildSelectedUsersCard(systemUsers),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return const ErpSectionHeaderCard(
      key: ValueKey('broadcast-page-title'),
      icon: Icons.chat_bubble_outline,
      title: 'Chat Support',
      badgeText: 'TEAM BROADCAST',
      subtitle: 'Send messages and updates to team members across WhatsApp and in-app notifications',
    );
  }

  Widget _buildComposerCard(List<BroadcastUser> systemUsers) {
    return _Panel(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Send To'),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final cards = [
                _buildAudienceOption(
                  MessageAudience.everyone,
                  'Everyone',
                  'All system users',
                  systemUsers,
                ),
                _buildAudienceOption(
                  MessageAudience.department,
                  'Department Wise',
                  'Select by user role',
                  systemUsers,
                ),
                _buildAudienceOption(
                  MessageAudience.individual,
                  'Individual User',
                  'Select specific user(s)',
                  systemUsers,
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      cards[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
          if (_audience == MessageAudience.department) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildDepartmentSelector(systemUsers),
          ],
          const SizedBox(height: AppSpacing.lg),
          _buildSectionTitle('Communication Channels'),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final cards = [
                _buildChannelOption(
                  title: 'WhatsApp',
                  subtitle: 'Send on WhatsApp',
                  icon: Icons.chat_rounded,
                  iconColor: AppColors.success,
                  value: _whatsAppEnabled,
                  onChanged: (value) => setState(() => _whatsAppEnabled = value),
                ),
                _buildChannelOption(
                  title: 'In-App Notification',
                  subtitle: 'Shown in ERP',
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFF4A6892),
                  value: _inAppEnabled,
                  onChanged: (value) => setState(() => _inAppEnabled = value),
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      cards[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildLabeledField(
            label: 'Subject',
            required: true,
            child: TextField(
              controller: _subjectController,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('Enter message subject'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildLabeledField(
            label: 'Message',
            required: true,
            child: TextField(
              controller: _messageController,
              minLines: 4,
              maxLines: 6,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                'Type the message you want to send...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: ErpButton(
              text: 'Send WhatsApp Message',
              icon: Icons.send_rounded,
              onPressed: () => _sendMessage(systemUsers),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceOption(
    MessageAudience audience,
    String title,
    String subtitle,
    List<BroadcastUser> systemUsers,
  ) {
    final selected = _audience == audience;
    return InkWell(
      onTap: () {
        setState(() {
          _audience = audience;
          if (audience == MessageAudience.everyone) {
            _selectedUserIds
              ..clear()
              ..addAll(systemUsers.map((u) => u.id));
          } else if (audience == MessageAudience.department && _department != null) {
            _selectedUserIds
              ..clear()
              ..addAll(
                systemUsers
                    .where((u) => u.department == _department)
                    .map((u) => u.id),
              );
          }
        });
      },
      borderRadius: AppRadius.smBorderRadius,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: AppRadius.smBorderRadius,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.textDisabled,
              size: 17,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentSelector(List<BroadcastUser> systemUsers) {
    final departments = systemUsers.map((u) => u.department).toSet().toList()..sort();
    return DropdownButtonFormField<String>(
      initialValue: departments.contains(_department) ? _department : (departments.isNotEmpty ? departments.first : null),
      decoration: _inputDecoration('Select department / role'),
      items: departments
          .map(
            (dept) => DropdownMenuItem(value: dept, child: Text(dept)),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _department = value;
          _selectedUserIds
            ..clear()
            ..addAll(
              systemUsers
                  .where((u) => u.department == value)
                  .map((u) => u.id),
            );
        });
      },
    );
  }

  Widget _buildChannelOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final enabled = onChanged != null;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: enabled ? (next) => onChanged(next ?? false) : null,
            activeColor: AppColors.success,
            visualDensity: VisualDensity.compact,
          ),
          Icon(icon, color: iconColor, size: 19),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label, required: required),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }

  Widget _buildSelectedUsersCard(List<BroadcastUser> systemUsers) {
    final filteredUsers = _getFilteredUsers(systemUsers);
    final selectedUsers = _getSelectedUsers(systemUsers);

    return _Panel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected Users (${selectedUsers.length})',
                  style: AppTextStyles.h3.copyWith(fontSize: 15),
                ),
              ),
              if (selectedUsers.isNotEmpty) ...[
                TextButton(
                  onPressed: () => _showWhatsAppNumbers(systemUsers),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Text('Numbers', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => setState(_selectedUserIds.clear),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('Search by name, role or phone...').copyWith(
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: filteredUsers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No users match your search.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (context, index) =>
                        _buildUserRow(filteredUsers[index]),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAllUsersDialog(systemUsers),
              icon: const Icon(Icons.groups_rounded, size: 17),
              label: Text('View All ${systemUsers.length} Users'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(38),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smBorderRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(BroadcastUser user) {
    final selected = _selectedUserIds.contains(user.id);
    return InkWell(
      onTap: () => _toggleUser(user),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => _toggleUser(user),
              visualDensity: VisualDensity.compact,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            CircleAvatar(
              radius: 14,
              backgroundColor: user.avatarColor,
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user.department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                user.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: AppColors.danger)),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String? hintText, {
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted, fontSize: 13),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      counterStyle: AppTextStyles.caption.copyWith(fontSize: 9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: AppRadius.smBorderRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smBorderRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smBorderRadius,
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  void _toggleUser(BroadcastUser user) {
    setState(() {
      if (!_selectedUserIds.add(user.id)) {
        _selectedUserIds.remove(user.id);
      }
    });
  }

  void _sendMessage(List<BroadcastUser> systemUsers) {
    final selectedUsers = _getSelectedUsers(systemUsers);
    if (selectedUsers.isEmpty) {
      _showSnackBar('Select at least one user to send this message.');
      return;
    }
    if (!_whatsAppEnabled && !_inAppEnabled) {
      _showSnackBar('Select at least one communication channel.');
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      _showSnackBar('Enter a subject before sending.');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showSnackBar('Enter a message before sending.');
      return;
    }

    final subject = _subjectController.text.trim();
    final body = _messageController.text.trim();
    final message = '*$subject*\n\n$body';

    if (_whatsAppEnabled) {
      if (selectedUsers.length == 1) {
        final targetUser = selectedUsers.first;
        DocumentSharingService.shareToWhatsApp(
          phoneNumber: targetUser.phone,
          message: message,
        );
        _showSnackBar('Opening WhatsApp for ${targetUser.name}...');
      } else {
        // Automatically launch WhatsApp for the first user
        final firstUser = selectedUsers.first;
        DocumentSharingService.shareToWhatsApp(
          phoneNumber: firstUser.phone,
          message: message,
        );

        // Display multi-recipient helper dialog for one-click dispatch to other users
        _showMultiUserWhatsAppDialog(selectedUsers, message);
      }
    } else {
      _showSnackBar('In-app message prepared for ${selectedUsers.length} users.');
    }
  }

  void _showMultiUserWhatsAppDialog(List<BroadcastUser> users, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Send WhatsApp (${users.length} Users)', style: AppTextStyles.h3.copyWith(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 460,
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WhatsApp opened for ${users.first.name}. Click "Send" to open chat for each team member:',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (context, i) {
                    final user = users[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: user.avatarColor,
                            child: Text(
                              user.initials,
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                Text('${user.department} · ${user.phone}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              DocumentSharingService.shareToWhatsApp(
                                phoneNumber: user.phone,
                                message: message,
                              );
                            },
                            icon: const Icon(Icons.send_rounded, size: 13),
                            label: const Text('Send', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppNumbers(List<BroadcastUser> systemUsers) {
    final selectedUsers = _getSelectedUsers(systemUsers);
    final numbers = selectedUsers.map((user) => '${user.name} (${user.department}): ${user.phone}').join('\n');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WhatsApp Numbers'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Text(
              numbers.isEmpty ? 'No users selected.' : numbers,
              style: AppTextStyles.bodyRegular,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAllUsersDialog(List<BroadcastUser> systemUsers) {
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('All System Users (${systemUsers.length})'),
          content: SizedBox(
            width: 440,
            height: 480,
            child: ListView.builder(
              itemCount: systemUsers.length,
              itemBuilder: (context, index) {
                final user = systemUsers[index];
                return CheckboxListTile(
                  value: _selectedUserIds.contains(user.id),
                  onChanged: (_) {
                    _toggleUser(user);
                    setDialogState(() {});
                  },
                  secondary: CircleAvatar(
                    backgroundColor: user.avatarColor,
                    child: Text(user.initials),
                  ),
                  title: Text(user.name),
                  subtitle: Text('${user.department} · ${user.phone}'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
