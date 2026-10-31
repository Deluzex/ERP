import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_toast.dart';
import '../../../shared/providers/app_state_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierCtrl = TextEditingController(text: 'admin@deluzex.com');
  final _passwordCtrl = TextEditingController(text: 'Admin@123');
  String? _selectedRoleId = 'admin';
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isLoading = false;

  // Demo Preset Role Credentials matching Live PostgreSQL Seeds
  final List<Map<String, String>> _demoRoles = [
    {
      'roleId': 'admin',
      'roleName': 'Admin',
      'email': 'admin@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'sales_manager',
      'roleName': 'Sales Manager',
      'email': 'sales@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'inventory_manager',
      'roleName': 'Inventory Mgr',
      'email': 'inventory@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'purchase_manager',
      'roleName': 'Purchase Mgr',
      'email': 'purchase@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'production_manager',
      'roleName': 'Production Mgr',
      'email': 'production@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'accounts_manager',
      'roleName': 'Payments Manager',
      'email': 'accounts@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'project_manager',
      'roleName': 'Project Manager',
      'email': 'projects@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'report_viewer',
      'roleName': 'Auditor / Reports',
      'email': 'reports@deluzex.com',
      'pass': 'Admin@123',
    },
    {
      'roleId': 'data_entry',
      'roleName': 'Data Entry Clerk',
      'email': 'dataentry@deluzex.com',
      'pass': 'Admin@123',
    },
  ];

  IconData _getRoleIcon(String roleId) {
    switch (roleId) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'sales_manager':
        return Icons.point_of_sale_outlined;
      case 'inventory_manager':
        return Icons.inventory_2_outlined;
      case 'purchase_manager':
        return Icons.shopping_bag_outlined;
      case 'production_manager':
        return Icons.precision_manufacturing_outlined;
      case 'accounts_manager':
        return Icons.payments_outlined;
      case 'project_manager':
        return Icons.apartment_outlined;
      case 'report_viewer':
        return Icons.analytics_outlined;
      case 'data_entry':
        return Icons.keyboard_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  void _fillDemoCredentials(Map<String, String> demo) {
    setState(() {
      _identifierCtrl.text = demo['email']!;
      _passwordCtrl.text = demo['pass']!;
      _selectedRoleId = demo['roleId'];
      _errorMessage = null;
    });
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      ErpToast.showError(context, 'Please enter a valid email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    try {
      final success = await ref.read(authStateProvider.notifier).loginAsync(identifier, password, _selectedRoleId);
      if (success) {
        widget.onLoginSuccess();
      } else {
        setState(() {
          _errorMessage = 'Invalid username/password or selected role does not match assigned permissions.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 480;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F), // Deep Luxury Obsidian
      body: Stack(
        children: [
          // Warm Golden Ambient Glow centered behind the logo & login card
          _buildAtmosphericGlow(context),

          // Main Centered Content: Company Logo + Login Box
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Centered Company Logo
                      SizedBox(
                        height: 48,
                        child: SvgPicture.asset(
                          'assets/images/logo_white.svg',
                          height: 48,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          placeholderBuilder: (context) => Image.asset(
                            'assets/images/logo_white.png',
                            height: 48,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Login Box
                      _buildLoginFormCard(context, isCompact: isCompact),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ambient Glow centered directly behind the company logo & login card
  Widget _buildAtmosphericGlow(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Center ambient golden halo
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.15),
                radius: 0.95,
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
                  AppColors.primary.withValues(alpha: 0.07),
                  AppColors.primary.withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // Subtle bottom corner reflection
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, 0.9),
                radius: 0.75,
                colors: [
                  AppColors.primary.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Core Login Form Card
  Widget _buildLoginFormCard(BuildContext context, {required bool isCompact}) {
    final db = ref.watch(databaseServiceProvider);

    return Container(
      padding: EdgeInsets.all(isCompact ? 22 : 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading & Subtitle
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enterprise Portal Login',
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: isCompact ? 20 : 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to access your role-based workspace',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // Error Alert Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.dangerText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Username / Email / Mobile Input
            TextFormField(
              controller: _identifierCtrl,
              validator: (v) => Validators.requiredField(v, 'Username, Email, or Mobile required'),
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Username / Work Email / Mobile',
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                hintText: 'e.g. admin@deluzex.com',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppColors.primaryDark),
                filled: true,
                fillColor: AppColors.surfaceMuted.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password Input with show/hide
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              validator: (v) => Validators.requiredField(v, 'Password required'),
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.primaryDark),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.neutral500,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: AppColors.surfaceMuted.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Assigned Role Verification Selector
            Builder(
              builder: (context) {
                final roleExists = _selectedRoleId == null || db.roles.any((r) => r.id == _selectedRoleId);
                final safeRoleId = roleExists ? _selectedRoleId : null;
                final hasSelectedRole = safeRoleId != null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.primaryDark),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Assigned Role Verification',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: hasSelectedRole ? AppColors.primarySoft.withValues(alpha: 0.5) : AppColors.surfaceMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasSelectedRole ? AppColors.primary : AppColors.border,
                          width: hasSelectedRole ? 1.4 : 1.0,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: safeRoleId,
                          isExpanded: true,
                          isDense: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 6,
                          menuMaxHeight: 360,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.primaryDark,
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: const [
                                    Icon(Icons.shield_outlined, size: 18, color: AppColors.textMuted),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '(Auto-detect from user account)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...db.roles.map((r) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getRoleIcon(r.id),
                                          size: 18,
                                          color: AppColors.primaryDark,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            r.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ];
                          },
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: const [
                                  Icon(Icons.shield_outlined, size: 18, color: AppColors.textMuted),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '(Auto-detect from user account)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...db.roles.map((r) {
                              final isSelected = safeRoleId == r.id;
                              return DropdownMenuItem<String?>(
                                value: r.id,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getRoleIcon(r.id),
                                      size: 18,
                                      color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        r.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: AppColors.primaryDark,
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedRoleId = val),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ErpButton(
                text: _isLoading ? 'Authenticating...' : 'Sign In to Workspace',
                icon: _isLoading ? null : Icons.login_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleLogin,
              ),
            ),
            const SizedBox(height: 24),

            // Divider & Demo Role Presets
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 14, color: AppColors.primaryDark),
                      const SizedBox(width: 4),
                      Text(
                        'DEMO ROLE PRESETS',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
              ],
            ),
            const SizedBox(height: 12),

            // Refined Theme-Consistent Demo Role Pills (No Clashing Rainbow Colors!)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _demoRoles.map((demo) {
                final isSelected = _selectedRoleId == demo['roleId'];

                return InkWell(
                  onTap: () => _fillDemoCredentials(demo),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primarySoft : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getRoleIcon(demo['roleId']!),
                          size: 14,
                          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          demo['roleName']!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                '${AppConstants.appName} Enterprise • Role-Based Access Control Active',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
