import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

void main() {
  runApp(const ProviderScope(child: RouteCashApp()));
}

class RouteCashApp extends StatelessWidget {
  const RouteCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Route Cash',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      // Segue automaticamente o tema do Android.
      themeMode: ThemeMode.system,

      home: const AuthGate(),
    );
  }
}
