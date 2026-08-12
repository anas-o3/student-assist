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

  testWidgets('Password visibility control remains functional', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StudentAssistApp());

    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pump();

    expect(find.byTooltip('إخفاء كلمة المرور'), findsOneWidget);
  });

  testWidgets('Register link opens the register screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StudentAssistApp());

    final registerLink = find.text('إنشاء حساب جديد');
    await tester.ensureVisible(registerLink);
    await tester.pumpAndSettle();
    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    expect(find.text('الاسم الكامل'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
    expect(find.text('إنشاء الحساب'), findsOneWidget);
  });
}
