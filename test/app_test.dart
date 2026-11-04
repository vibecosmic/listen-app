import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_app/main.dart';

void main() {
  testWidgets('renders minimal app shell', (tester) async {
    await tester.pumpWidget(const ListenApp());
    expect(find.text('Listen — coming soon'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
