import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/grade.dart';
import 'package:student_assist/screens/student/grade_selection_screen.dart';
import 'package:student_assist/services/auth_service.dart';
import 'package:student_assist/services/grade_service.dart';
import 'package:student_assist/services/user_service.dart';

void main() {
  const grades = [
    Grade(gradeId: 'grade-1', name: 'اولى ثانوي', order: 1, isActive: true),
    Grade(gradeId: 'grade-2', name: 'ثانية ثانوي', order: 2, isActive: true),
    Grade(gradeId: 'grade-3', name: 'ثالثة ثانوي', order: 3, isActive: true),
  ];

  testWidgets('shows a loading state while grades are requested', (
    tester,
  ) async {
    final completer = Completer<List<Grade>>();
    await _pumpScreen(
      tester,
      gradeService: _FakeGradeService(loadCompleter: completer),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('جارٍ تحميل الصفوف الدراسية...'), findsOneWidget);

    completer.complete(grades);
    await tester.pumpAndSettle();
  });

  testWidgets('displays active grades ordered by order', (tester) async {
    await _pumpScreen(
      tester,
      gradeService: _FakeGradeService(
        grades: [grades[2], grades[0], grades[1]],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اولى ثانوي'), findsOneWidget);
    expect(find.text('ثانية ثانوي'), findsOneWidget);
    expect(find.text('ثالثة ثانوي'), findsOneWidget);

    final firstTop = tester.getTopLeft(find.text('اولى ثانوي')).dy;
    final secondTop = tester.getTopLeft(find.text('ثانية ثانوي')).dy;
    final thirdTop = tester.getTopLeft(find.text('ثالثة ثانوي')).dy;
    expect(firstTop, lessThan(secondTop));
    expect(secondTop, lessThan(thirdTop));
  });

  testWidgets('shows a safe load failure with retry action', (tester) async {
    await _pumpScreen(
      tester,
      gradeService: _FakeGradeService(loadShouldFail: true),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('تعذر تحميل الصفوف الدراسية. حاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('retry-grades-button')), findsOneWidget);
    expect(find.textContaining('private Firebase detail'), findsNothing);
  });

  testWidgets('submits selected grade for the authenticated user', (
    tester,
  ) async {
    final userService = _FakeUserService();
    await _pumpScreen(
      tester,
      gradeService: _FakeGradeService(grades: grades),
      userService: userService,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('grade-option-grade-2')));
    await tester.pump();
    final confirmButton = find.byKey(const Key('confirm-grade-button'));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(userService.selectCalls, 1);
    expect(userService.lastUid, 'authenticated-student');
    expect(userService.lastGradeId, 'grade-2');
    expect(find.byKey(const Key('grade-selection-success')), findsOneWidget);
    expect(find.text('تم حفظ صفك الدراسي بنجاح.'), findsWidgets);
  });

  testWidgets('prevents repeated submission while saving', (tester) async {
    final saveCompleter = Completer<void>();
    final userService = _FakeUserService(saveCompleter: saveCompleter);
    await _pumpScreen(
      tester,
      gradeService: _FakeGradeService(grades: grades),
      userService: userService,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('grade-option-grade-1')));
    await tester.pump();
    final confirmButton = find.byKey(const Key('confirm-grade-button'));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pump();

    expect(userService.selectCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    saveCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows safe feedback when grade saving fails', (tester) async {
    await _pumpScreen(
      tester,
      gradeService: _FakeGradeService(grades: grades),
      userService: _FakeUserService(saveShouldFail: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('grade-option-grade-3')));
    await tester.pump();
    final confirmButton = find.byKey(const Key('confirm-grade-button'));
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.text('تعذر حفظ الصف الدراسي. حاول مرة أخرى.'), findsOneWidget);
    expect(find.textContaining('private Firebase detail'), findsNothing);
    expect(find.byKey(const Key('grade-selection-success')), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required GradeService gradeService,
  UserService? userService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: GradeSelectionScreen(
        gradeService: gradeService,
        userService: userService ?? _FakeUserService(),
        authService: _FakeAuthService(),
      ),
    ),
  );
}

class _FakeGradeService extends GradeService {
  _FakeGradeService({
    this.grades = const [],
    this.loadCompleter,
    this.loadShouldFail = false,
  });

  final List<Grade> grades;
  final Completer<List<Grade>>? loadCompleter;
  final bool loadShouldFail;

  @override
  Future<List<Grade>> loadActiveGrades() async {
    if (loadShouldFail) {
      throw const GradeFailure('تعذر تحميل الصفوف الدراسية. حاول مرة أخرى.');
    }
    return loadCompleter?.future ?? List.of(grades);
  }
}

class _FakeUserService extends UserService {
  _FakeUserService({this.saveCompleter, this.saveShouldFail = false});

  final Completer<void>? saveCompleter;
  final bool saveShouldFail;
  int selectCalls = 0;
  String? lastUid;
  String? lastGradeId;

  @override
  Future<void> selectGrade({
    required String uid,
    required String gradeId,
  }) async {
    selectCalls++;
    lastUid = uid;
    lastGradeId = gradeId;
    if (saveShouldFail) {
      throw const UserGradeSelectionFailure(
        'تعذر حفظ الصف الدراسي. حاول مرة أخرى.',
      );
    }
    await saveCompleter?.future;
  }
}

class _FakeAuthService extends AuthService {
  @override
  String? get currentUserUid => 'authenticated-student';
}
