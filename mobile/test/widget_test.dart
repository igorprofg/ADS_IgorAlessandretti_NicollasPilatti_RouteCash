import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('Route Cash inicia corretamente', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RouteCashApp()));

    expect(find.text('Route Cash'), findsOneWidget);
    expect(find.text('Criar conta'), findsWidgets);
  });
}
