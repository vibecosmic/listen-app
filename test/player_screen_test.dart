import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_player/main.dart';

void main() {
  testWidgets('offline preview exposes audio limitation and navigation',
      (tester) async {
    await tester.pumpWidget(const ListenApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Audio is not bundled yet'), findsOneWidget);
    expect(find.text('Hello.'), findsOneWidget);
    expect(find.text('How are you?'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('transcript can be hidden without network or audio',
      (tester) async {
    await tester.pumpWidget(const ListenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show transcript'));
    await tester.pumpAndSettle();
    expect(find.text('Hello.'), findsNothing);
  });
}
