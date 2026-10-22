import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
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

  // Demo Preset Role Credentials matching Live PostgreSQL Seeds
  final List<Map<String, String>> _demoRoles = [
    {
      'roleId': 'admin',
      'roleName': 'Admin',
      'email': 'admin@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF1E3A8A',
      'icon': 'shield',
    },
    {
      'roleId': 'sales_manager',
      'roleName': 'Sales Manager',
      'email': 'sales@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF16A34A',
      'icon': 'point_of_sale',
    },
    {
      'roleId': 'inventory_manager',
      'roleName': 'Inventory Mgr',
      'email': 'inventory@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF2563EB',
      'icon': 'inventory_2',
    },
    {
      'roleId': 'purchase_manager',
      'roleName': 'Purchase Mgr',
      'email': 'purchase@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF9333EA',
      'icon': 'shopping_bag',
    },
    {
      'roleId': 'production_manager',
      'roleName': 'Production Mgr',
      'email': 'production@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF4F46E5',
      'icon': 'precision_manufacturing',
    },
    {
      'roleId': 'accounts_manager',
      'roleName': 'Payments Manager',
      'email': 'accounts@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF0D9488',
      'icon': 'payments',
    },
    {
      'roleId': 'project_manager',
      'roleName': 'Project Manager',
      'email': 'projects@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF7C3AED',
      'icon': 'apartment',
    },
    {
      'roleId': 'report_viewer',
      'roleName': 'Auditor / Reports',
      'email': 'reports@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFFD97706',
      'icon': 'analytics',
    },
    {
      'roleId': 'data_entry',
      'roleName': 'Data Entry Clerk',
      'email': 'dataentry@deluzex.com',
      'pass': 'Admin@123',
      'color': '0xFF475569',
      'icon': 'keyboard',
    },
  ];

  void _fillDemoCredentials(Map<String, String> demo) {
    setState(() {
      _identifierCtrl.text = demo['email']!;
      _passwordCtrl.text = demo['pass']!;
      _selectedRoleId = demo['roleId'];
      _errorMessage = null;
    });
  }

  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

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
    final db = ref.watch(databaseServiceProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 480;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek Slate Dark Background
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: isCompact ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 480),
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 20 : 36),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.xlBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
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
                      // Logo & Brand Header
                      SizedBox(
                        height: 38,
                        child: SvgPicture.asset(
                          'assets/images/logo_dark.svg',
                          height: 38,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          placeholderBuilder: (context) => Image.asset(
                            'assets/images/logo_dark.png',
                            height: 38,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Enterprise Portal Login', style: AppTextStyles.h1),
                      const SizedBox(height: 4),
                      Text('Sign in to continue to your workspace', style: AppTextStyles.subtitle),
                      const SizedBox(height: 24),

                      // Error Alert Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w500),
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
                        decoration: const InputDecoration(
                          labelText: 'Username / Work Email / Mobile',
                          hintText: 'e.g. admin@deluxex.com or 9876500001',
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Input with show/hide
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        validator: (v) => Validators.requiredField(v, 'Password required'),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown Selector (Optional / Auto-identified) - styled like ErpFilterDropdown
                      Builder(
                        builder: (context) {
                          final roleExists = _selectedRoleId == null || db.roles.any((r) => r.id == _selectedRoleId);
                          final safeRoleId = roleExists ? _selectedRoleId : null;
                          final hasSelectedRole = safeRoleId != null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned Role Verification',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: hasSelectedRole ? AppColors.primaryDark : const Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 44,
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: hasSelectedRole ? AppColors.primarySoft.withValues(alpha: 0.45) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasSelectedRole ? AppColors.primary : const Color(0xFFE2E8F0),
                                    width: hasSelectedRole ? 1.2 : 1.0,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x04000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    canvasColor: Colors.white,
                                    highlightColor: AppColors.primarySoft,
                                    hoverColor: AppColors.primarySoft.withValues(alpha: 0.5),
                                    splashColor: AppColors.primaryLight.withValues(alpha: 0.25),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: safeRoleId,
                                      isExpanded: true,
                                      isDense: true,
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      elevation: 4,
                                      menuMaxHeight: 360,
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: hasSelectedRole ? AppColors.primaryDark : AppColors.primary,
                                      ),
                                      selectedItemBuilder: (BuildContext context) {
                                        return [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              children: const [
                                                Icon(Icons.shield_outlined, size: 18, color: Color(0xFF64748B)),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '(Auto-detect from user account)',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF64748B),
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
                                                      Icons.shield_outlined,
                                                      size: 18,
                                                      color: hasSelectedRole ? AppColors.primaryDark : const Color(0xFF64748B),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        r.name,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: hasSelectedRole ? FontWeight.w600 : FontWeight.w500,
                                                          color: hasSelectedRole ? AppColors.primaryDark : const Color(0xFF1E293B),
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
                                              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF64748B)),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '(Auto-detect from user account)',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFF64748B),
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
                                                  Icons.shield_outlined,
                                                  size: 18,
                                                  color: isSelected ? AppColors.primaryDark : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    r.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                      color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
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
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ErpButton(
                          text: _isLoading ? 'Signing In...' : 'Sign In to Workspace',
                          icon: _isLoading ? null : Icons.login_rounded,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _handleLogin,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider & 1-Click Role Switcher section
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'DEMO ROLE PRESETS',
                              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _demoRoles.map((demo) {
                          final isSelected = _selectedRoleId == demo['roleId'];
                          final colorVal = int.parse(demo['color']!);
                          final color = Color(colorVal);

                          return InkWell(
                            onTap: () => _fillDemoCredentials(demo),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? color : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 5,
                                    backgroundColor: color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    demo['roleName']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? color : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '${AppConstants.appName} Enterprise • Role-Based Access Control Active',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDisabled, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
