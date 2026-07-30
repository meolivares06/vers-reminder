import 'package:flutter_test/flutter_test.dart';
import 'package:vers_reminder/main.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const VersReminderApp());
    expect(find.byType(VersReminderApp), findsOneWidget);
  });
}
