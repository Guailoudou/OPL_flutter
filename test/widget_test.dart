import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/ui/pages/home_shell.dart';

void main() {
  testWidgets('shows boot progress without native plugins', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeShell(booting: true, bootError: null),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows initialization errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          HomeShell(booting: false, bootError: 'Unable to read configuration'),
    ));
    expect(find.text('Unable to read configuration'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
