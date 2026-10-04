import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/users/presentation/register_page.dart';

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
      home: const RegisterPage(),
    );
  }
}
