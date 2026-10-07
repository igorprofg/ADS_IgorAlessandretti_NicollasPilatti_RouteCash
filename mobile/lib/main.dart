import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/auth_gate.dart';

void main() {
  runApp(const ProviderScope(child: RouteCashApp()));
}

class RouteCashApp extends StatelessWidget {
  const RouteCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Route Cash',
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}
