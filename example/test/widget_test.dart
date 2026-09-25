import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showcase renders every feature lab', (tester) async {
    await tester.pumpWidget(const SvfExampleApp());

    expect(find.text('SVF Showcase'), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-end-to-end')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-ai-sdk')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-voice')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-downloads')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-agents')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-facade')), findsOneWidget);
    expect(find.byKey(const ValueKey('run-end-to-end')), findsOneWidget);
  });

  testWidgets('offline workflow transcribes, structures, streams, and agents', (
    tester,
  ) async {
    await tester.pumpWidget(const SvfExampleApp());
    await tester.tap(find.byKey(const ValueKey('run-end-to-end')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('transcript')), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(
      find.text('Audio source captured and retained for review.'),
      findsOneWidget,
    );

    final exportButton = find.byKey(const ValueKey('approve-export'));
    await tester.drag(
      find.byKey(const ValueKey('end-to-end-page')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(exportButton);
    await tester.pumpAndSettle();
    expect(find.text('Reviewed record exported'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-ai-sdk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('generate-text')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stream-text')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stream-output')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('event-stream')));
    await tester.pumpAndSettle();
    expect(find.text('Normalized events'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-loop')));
    await tester.pumpAndSettle();
    expect(find.text('Approve tool call?'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-output')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('generate-json')));
    await tester.pumpAndSettle();
    expect(find.text('Validated JSON'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stream-object')));
    await tester.pumpAndSettle();
    expect(find.text('streamObject completed and validated.'), findsOneWidget);
  });

  testWidgets('voice lab exposes live transcription and synthesis actions', (
    tester,
  ) async {
    await tester.pumpWidget(const SvfExampleApp());
    await tester.tap(find.byKey(const ValueKey('tab-voice')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('live-transcription')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Final:'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('synthesize-speech')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Generated '), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('batch-transcription')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('audio-details')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('router-transcription')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Router selected'), findsOneWidget);
  });

  testWidgets('agents and facade map explain advanced integration points', (
    tester,
  ) async {
    await tester.pumpWidget(const SvfExampleApp());
    await tester.tap(find.byKey(const ValueKey('tab-agents')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approval-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('approval-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('run-agent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agents-result')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-facade')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('facade-page')), findsOneWidget);
    expect(find.text('OpenRouter'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('facade-page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('streamObject<T>'), findsOneWidget);
  });

  testWidgets(
    'downloads lab renders model manifests without starting a network request',
    (tester) async {
      await tester.pumpWidget(const SvfExampleApp());
      await tester.tap(find.byKey(const ValueKey('tab-downloads')));
      await tester.pumpAndSettle();

      expect(find.text('Whisper Tiny (English)'), findsOneWidget);
      expect(find.text('Google Gemma 2B Instruct (4-bit)'), findsOneWidget);
      expect(find.text('Download'), findsWidgets);
    },
  );
}
