import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentdeck_mobile/main.dart';
import 'package:agentdeck_mobile/theme/terminal_theme.dart';

void main() {
  testWidgets('AgentDeck App theme and structure validation', (WidgetTester tester) async {
    const app = AgentDeckApp();
    expect(app, isNotNull);
    expect(TerminalTheme.darkTheme.brightness, equals(Brightness.dark));
    expect(TerminalColors.background.toARGB32(), equals(0xFF000000));
  });
}
