import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('end-to-end showcase flow is usable on a real target', (
    tester,
  ) async {
    await tester.pumpWidget(const SvfExampleApp());

    await tester.tap(find.byKey(const ValueKey('run-end-to-end')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transcript')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-ai-sdk')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('generate-object')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-voice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('live-transcription')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Final:'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-agents')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('approval-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('run-agent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agents-result')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-facade')));
    await tester.pumpAndSettle();
    expect(find.text('OpenRouter'), findsOneWidget);
  });
}
