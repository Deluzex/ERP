import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/login_screen.dart';
import '../shared/providers/app_state_providers.dart';
import '../shared/providers/subscription_provider.dart';
import '../shared/widgets/user_activity_detector.dart';
import 'app_shell.dart';
import 'constants/app_constants.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class ErpApplication extends ConsumerStatefulWidget {
  const ErpApplication({super.key});

  @override
  ConsumerState<ErpApplication> createState() => _ErpApplicationState();
}

class _ErpApplicationState extends ConsumerState<ErpApplication> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isBootstrapComplete = ref.read(isSessionBootstrapCompleteProvider);
      if (!isBootstrapComplete) {
        await ref.read(authStateProvider.notifier).restoreSession();
        await ref.read(subscriptionProvider.notifier).fetchStatus();
        if (mounted) {
          ref.read(isSessionBootstrapCompleteProvider.notifier).state = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBootstrapComplete = ref.watch(isSessionBootstrapCompleteProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return UserActivityDetector(
          onUserActivity: () {
            if (ref.read(isAuthenticatedProvider)) {
              ref.read(authStateProvider.notifier).recordUserActivity();
            }
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: !isBootstrapComplete
          ? const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            )
          : (isAuthenticated
              ? const AppShell()
              : LoginScreen(
                  onLoginSuccess: () {
                    ref.read(subscriptionProvider.notifier).fetchStatus();
                  },
                )),
    );
  }
}
