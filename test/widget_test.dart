import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/app.dart';

void main() {
  testWidgets('Student Assist app loads successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StudentAssistApp());

    expect(find.bySemanticsLabel('شعار مساعد طلبة الثانوية'), findsOneWidget);
    expect(find.text('مرحباً بعودتك'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
