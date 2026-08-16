import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/grade.dart';
import 'package:student_assist/models/subject.dart';
import 'package:student_assist/models/user_profile.dart';
import 'package:student_assist/screens/auth/login_screen.dart';
import 'package:student_assist/screens/student/grade_selection_screen.dart';
import 'package:student_assist/screens/student/student_home_screen.dart';
import 'package:student_assist/services/auth_service.dart';
import 'package:student_assist/services/grade_service.dart';
import 'package:student_assist/services/subject_service.dart';
import 'package:student_assist/services/user_service.dart';

void main() {
  testWidgets('student without grade is routed to grade selection', (
    tester,
  ) async {
    await _pumpLogin(tester, profile: _profile(gradeId: null));
    await _submitLogin(tester);

    expect(find.byType(GradeSelectionScreen), findsOneWidget);
    expect(find.byType(StudentHomeScreen), findsNothing);
  });

  testWidgets('student with grade is routed to home with correct gradeId', (
    tester,
  ) async {
    await _pumpLogin(tester, profile: _profile(gradeId: 'grade-2'));
    await _submitLogin(tester);

    expect(find.byType(StudentHomeScreen), findsOneWidget);
    expect(
      tester.widget<StudentHomeScreen>(find.byType(StudentHomeScreen)).gradeId,
      'grade-2',
    );
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('missing profile shows safe error without navigation', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      failure: const UserProfileFailure(
        reason: UserProfileFailureReason.missingProfile,
        message: 'لم يتم العثور على ملف المستخدم.',
      ),
    );
    await _submitLogin(tester);

    expect(find.text('لم يتم العثور على ملف المستخدم.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(StudentHomeScreen), findsNothing);
  });

  testWidgets('invalid profile shows safe error without navigation', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      failure: const UserProfileFailure(
        reason: UserProfileFailureReason.invalidProfile,
        message: 'بيانات ملف المستخدم غير صالحة.',
      ),
    );
    await _submitLogin(tester);

    expect(find.text('بيانات ملف المستخدم غير صالحة.'), findsOneWidget);
    expect(find.byType(StudentHomeScreen), findsNothing);
  });

  testWidgets('invalid role shows safe error without student navigation', (
    tester,
  ) async {
    await _pumpLogin(tester, profile: _profile(role: 'teacher'));
    await _submitLogin(tester);

    expect(
      find.text('تعذر تحديد صلاحية الحساب. تواصل مع إدارة التطبيق.'),
      findsOneWidget,
    );
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(StudentHomeScreen), findsNothing);
  });

  testWidgets('admin sees deferred message without student navigation', (
    tester,
  ) async {
    await _pumpLogin(tester, profile: _profile(role: 'admin'));
    await _submitLogin(tester);

    expect(
      find.text('تم تسجيل الدخول، لكن واجهة الإدارة غير متاحة حالياً.'),
      findsOneWidget,
    );
    expect(find.byType(StudentHomeScreen), findsNothing);
    expect(find.byType(GradeSelectionScreen), findsNothing);
  });

  testWidgets('back cannot return to login after student routing', (
    tester,
  ) async {
    await _pumpLogin(tester, profile: _profile(gradeId: 'grade-1'));
    await _submitLogin(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(StudentHomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('temporary debug entries no longer exist', (tester) async {
    await _pumpLogin(tester, profile: _profile());

    expect(find.byKey(const Key('debug-open-student-home')), findsNothing);
    expect(find.byKey(const Key('debug-open-grade-selection')), findsNothing);
    expect(find.textContaining('للاختبار المؤقت'), findsNothing);
  });
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  UserProfile? profile,
  UserProfileFailure? failure,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: LoginScreen(
        authService: _FakeAuthService(),
        userService: _FakeUserService(profile: profile, failure: failure),
        gradeSelectionScreenBuilder: () => GradeSelectionScreen(
          gradeService: _FakeGradeService(),
          userService: _FakeUserService(profile: profile),
          authService: _FakeAuthService(),
          studentHomeScreenBuilder: _buildStudentHome,
        ),
        studentHomeScreenBuilder: _buildStudentHome,
      ),
    ),
  );
}

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
  await tester.enterText(find.byType(TextField).at(1), 'password');
  final button = find.widgetWithText(ElevatedButton, 'تسجيل الدخول');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Widget _buildStudentHome(String gradeId) {
  return StudentHomeScreen(
    gradeId: gradeId,
    subjectService: _FakeSubjectService(),
  );
}

UserProfile _profile({String role = 'student', String? gradeId = 'grade-1'}) {
  return UserProfile(
    userId: 'student-uid',
    name: 'طالب تجريبي',
    email: 'student@example.com',
    role: role,
    gradeId: gradeId,
    createdAt: DateTime.utc(2026),
  );
}

class _FakeAuthService extends AuthService {
  @override
  String? get currentUserUid => 'student-uid';

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
}

class _FakeUserService extends UserService {
  _FakeUserService({this.profile, this.failure});

  final UserProfile? profile;
  final UserProfileFailure? failure;

  @override
  Future<UserProfile> getUserProfile(String uid) async {
    if (failure case final failure?) throw failure;
    return profile ?? _profile();
  }

  @override
  Future<void> selectGrade({
    required String uid,
    required String gradeId,
  }) async {}
}

class _FakeGradeService extends GradeService {
  @override
  Future<List<Grade>> loadActiveGrades() async => const [
    Grade(gradeId: 'grade-1', name: 'اولى ثانوي', order: 1, isActive: true),
  ];
}

class _FakeSubjectService extends SubjectService {
  @override
  Future<List<Subject>> loadActiveSubjectsForGrade(String gradeId) async => [];
}
