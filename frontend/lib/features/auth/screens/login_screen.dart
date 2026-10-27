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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F), // Deep Luxury Obsidian
      body: Stack(
        children: [
          // Responsive Atmospheric Ambient Warm Gold Glow (Centered on Phone, Dual-Zone on Desktop)
          _buildAtmosphericGlow(context, isDesktop),

          // Main Responsive Content
          SafeArea(
            child: isDesktop ? _buildDesktopSplitLayout(context) : _buildCenteredMobileLayout(context),
          ),
        ],
      ),
    );
  }

  /// Seamless Atmospheric Glow: Accurately aligned behind the 'de luzex' logo without any circular edges or cutoff boundaries
  Widget _buildAtmosphericGlow(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Base obsidian canvas with warm golden glow centered directly behind the 'de luzex' logo & showcase
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.58, -0.72),
                  radius: 1.15,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.06),
                    AppColors.primary.withValues(alpha: 0.015),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // Secondary soft ambient backlight framing the right login card
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.65, -0.05),
                  radius: 0.85,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.07),
                    AppColors.primary.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Phone & Tablet Mobile View: Seamless full-screen ambient wash centered directly behind the top 'de luzex' logo
    return Stack(
      fit: StackFit.expand,
      children: [
        // Top-center ambient wash aligned directly with the logo
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.78),
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
                  AppColors.primary.withValues(alpha: 0.05),
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

  /// Desktop View: Premium Split-Screen Enterprise Showcase
  Widget _buildDesktopSplitLayout(BuildContext context) {
    return Row(
      children: [
        // Left Column: Brand Showcase & Value Proposition
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.sidebarBorder.withValues(alpha: 0.6), width: 1),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Brand Header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 42,
                        child: SvgPicture.asset(
                          'assets/images/logo_white.svg',
                          height: 42,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          placeholderBuilder: (context) => Image.asset(
                            'assets/images/logo_white.png',
                            height: 42,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ENTERPRISE MANUFACTURING & INVENTORY',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Precision Engineering.\nComplete Operational Control.',
                        style: AppTextStyles.h1.copyWith(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Seamless, real-time coordination across multi-tier bill of materials, shop-floor production, stock movements, and statutory tax invoices.',
                        style: AppTextStyles.bodyRegular.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Center: Feature Grid Cards
                  Column(
                    children: [
                      _buildShowcaseFeature(
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'Multi-Level BOM & WIP Tracking',
                        description: 'Real-time stage-wise material consumption, scrap calculation, and direct manufacturing costing.',
                      ),
                      const SizedBox(height: 14),
                      _buildShowcaseFeature(
                        icon: Icons.receipt_long_outlined,
                        title: 'Statutory GST & Revenue Operations',
                        description: 'Direct sales invoices, delivery challans, credit notes, and automated customer ledgers.',
                      ),
                      const SizedBox(height: 14),
                      _buildShowcaseFeature(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Multi-Role Granular RBAC',
                        description: 'Strict security boundaries across Admin, Inventory, Production, Sales, and Payments teams.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right Column: Sign In Form
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildLoginFormCard(context, isCompact: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile & Tablet View: Centered Luxury Card
  Widget _buildCenteredMobileLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 480;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 24,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Brand Logo
              SizedBox(
                height: 38,
                child: SvgPicture.asset(
                  'assets/images/logo_white.svg',
                  height: 38,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  placeholderBuilder: (context) => Image.asset(
                    'assets/images/logo_white.png',
                    height: 38,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Form Card
              _buildLoginFormCard(context, isCompact: isCompact),
            ],
          ),
        ),
      ),
    );
  }

  /// Feature Showcase Item for Desktop View
  Widget _buildShowcaseFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sidebarBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
