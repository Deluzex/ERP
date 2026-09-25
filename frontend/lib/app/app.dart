import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/login_screen.dart';
import '../shared/providers/app_state_providers.dart';
import 'app_shell.dart';
import 'constants/app_constants.dart';
import 'theme/app_theme.dart';

class ErpApplication extends ConsumerWidget {
  const ErpApplication({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SelectionArea(
        child: isAuthenticated
            ? const AppShell()
            : LoginScreen(
                onLoginSuccess: () {
                  // State notifier updates isAuthenticatedProvider automatically
                },
              ),
      ),
    );
  }
}
