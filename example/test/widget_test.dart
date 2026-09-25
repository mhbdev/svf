import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('SvfExampleApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SvfExampleApp());
    expect(find.text('Smart Voice Foundation (SVF)'), findsOneWidget);
    expect(find.text('Voice-to-Form (HITL)'), findsOneWidget);
    expect(find.text('Model Downloader'), findsOneWidget);
  });
}
