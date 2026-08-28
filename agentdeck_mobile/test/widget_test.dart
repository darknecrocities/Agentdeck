import 'package:flutter_test/flutter_test.dart';
import 'package:agentdeck_mobile/main.dart';

void main() {
  testWidgets('AgentDeck App initializes', (WidgetTester tester) async {
    await tester.pumpWidget(const AgentDeckApp());
    expect(find.byType(AgentDeckApp), findsOneWidget);
  });
}
