import 'package:flutter/material.dart';
import '../features/auth/screens/login_screen.dart';
import 'app_shell.dart';
import 'constants/app_constants.dart';
import 'theme/app_theme.dart';

class ErpApplication extends StatefulWidget {
  const ErpApplication({super.key});

  @override
  State<ErpApplication> createState() => _ErpApplicationState();
}

class _ErpApplicationState extends State<ErpApplication> {
  bool _isAuthenticated = true; // Set to true by default for immediate workspace access

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _isAuthenticated
          ? const AppShell()
          : LoginScreen(
              onLoginSuccess: () {
                setState(() => _isAuthenticated = true);
              },
            ),
    );
  }
}
