import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/app.dart';

void main() {
  testWidgets(
    'Student Assist app loads successfully',
    (WidgetTester tester) async {
      await tester.pumpWidget(const StudentAssistApp());

      expect(find.text('مساعد الطالب'), findsOneWidget);
    },
  );
}