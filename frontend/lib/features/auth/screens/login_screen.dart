import 'package:flutter/material.dart';
import '../../../app/constants/app_constants.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'alex.sterling@deluxex.com');
  final _passwordCtrl = TextEditingController(text: 'deluxex2026');
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebarBackground,
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.xlBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Brand
                Image.asset(
                  'assets/images/logo.png',
                  height: 42,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'd',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Welcome back', style: AppTextStyles.h1),
                const SizedBox(height: 4),
                Text('Sign in to access your ERP manufacturing & stock portal', style: AppTextStyles.subtitle),
                const SizedBox(height: 28),

                TextFormField(
                  controller: _emailCtrl,
                  validator: Validators.email,
                  decoration: const InputDecoration(
                    labelText: 'Work Email Address',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 16),

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
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ErpButton(
                    text: 'Sign In to Workspace',
                    icon: Icons.login,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onLoginSuccess();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '${AppConstants.appName} • ${AppConstants.appVersion}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDisabled, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
