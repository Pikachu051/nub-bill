import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nubbill/app.dart';

void main() {
  testWidgets('App shows bootstrap splash while services initialize', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseBootstrapProvider.overrideWith((ref) => completer.future),
        ],
        child: const App(),
      ),
    );

    expect(find.byType(App), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
  });
}
