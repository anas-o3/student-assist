import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/app.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/screens/auth/forgot_password_screen.dart';
import 'package:student_assist/screens/auth/login_screen.dart';
import 'package:student_assist/screens/auth/register_screen.dart';
import 'package:student_assist/services/auth_service.dart';

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

  testWidgets('Forgot password link opens the recovery screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StudentAssistApp());

    final forgotPasswordLink = find.text('نسيت كلمة المرور؟');
    await tester.ensureVisible(forgotPasswordLink);
    await tester.pumpAndSettle();
    await tester.tap(forgotPasswordLink);
    await tester.pumpAndSettle();

    expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('إرسال رابط الاستعادة'), findsOneWidget);
    expect(find.text('العودة لتسجيل الدخول'), findsOneWidget);

    await tester.tap(find.text('العودة لتسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('مرحباً بعودتك'), findsOneWidget);
  });

  test('Firebase authentication errors have safe Arabic messages', () {
    const expectedMessages = {
      'invalid-email': 'البريد الإلكتروني غير صالح.',
      'user-not-found': 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.',
      'wrong-password': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'invalid-credential': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'email-already-in-use': 'يوجد حساب مسجل بهذا البريد الإلكتروني بالفعل.',
      'weak-password': 'كلمة المرور ضعيفة. اختر كلمة مرور أقوى.',
      'too-many-requests': 'تم إجراء محاولات كثيرة. حاول مرة أخرى لاحقاً.',
      'network-request-failed':
          'تعذر الاتصال بالشبكة. تحقق من اتصالك بالإنترنت.',
    };

    for (final entry in expectedMessages.entries) {
      expect(AuthService.messageForCode(entry.key), entry.value);
    }
    expect(
      AuthService.messageForCode('unknown-code'),
      'تعذر إكمال العملية. حاول مرة أخرى.',
    );
  });

  testWidgets('Login submits trimmed email through AuthService', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    await _pumpAuthScreen(tester, LoginScreen(authService: authService));

    await tester.enterText(
      find.byType(TextField).at(0),
      '  student@example.com  ',
    );
    await tester.enterText(find.byType(TextField).at(1), 'secret-password');
    final loginButton = find.widgetWithText(ElevatedButton, 'تسجيل الدخول');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(authService.signInCalls, 1);
    expect(authService.lastEmail, 'student@example.com');
    expect(authService.lastPassword, 'secret-password');
    expect(find.text('تم تسجيل الدخول بنجاح.'), findsOneWidget);
  });

  testWidgets('Register creates a student account through AuthService', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    await _pumpAuthScreen(tester, RegisterScreen(authService: authService));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'طالب تجريبي');
    await tester.enterText(fields.at(1), '  student@example.com  ');
    await tester.enterText(fields.at(2), 'secret-password');
    await tester.enterText(fields.at(3), 'secret-password');
    final registerButton = find.widgetWithText(ElevatedButton, 'إنشاء الحساب');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(authService.registerCalls, 1);
    expect(authService.lastEmail, 'student@example.com');
    expect(authService.lastPassword, 'secret-password');
    expect(find.text('تم إنشاء الحساب بنجاح.'), findsOneWidget);
  });

  testWidgets('Forgot password sends reset email through AuthService', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    await _pumpAuthScreen(
      tester,
      ForgotPasswordScreen(authService: authService),
    );

    await tester.enterText(find.byType(TextField), '  student@example.com  ');
    final resetButton = find.widgetWithText(
      ElevatedButton,
      'إرسال رابط الاستعادة',
    );
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(authService.resetCalls, 1);
    expect(authService.lastEmail, 'student@example.com');
    expect(
      find.text('تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpAuthScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: screen),
  );
}

class _FakeAuthService extends AuthService {
  int registerCalls = 0;
  int signInCalls = 0;
  int resetCalls = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    registerCalls++;
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetCalls++;
    lastEmail = email;
  }
}
