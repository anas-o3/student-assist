import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/grade.dart';
import '../../services/auth_service.dart';
import '../../services/grade_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_logo.dart';

class GradeSelectionScreen extends StatefulWidget {
  const GradeSelectionScreen({
    super.key,
    this.gradeService,
    this.userService,
    this.authService,
  });

  final GradeService? gradeService;
  final UserService? userService;
  final AuthService? authService;

  @override
  State<GradeSelectionScreen> createState() => _GradeSelectionScreenState();
}

class _GradeSelectionScreenState extends State<GradeSelectionScreen> {
  GradeService? _defaultGradeService;
  UserService? _defaultUserService;
  AuthService? _defaultAuthService;

  List<Grade> _grades = const [];
  String? _selectedGradeId;
  String? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _selectionCompleted = false;

  GradeService get _gradeService =>
      widget.gradeService ?? (_defaultGradeService ??= GradeService());
  UserService get _userService =>
      widget.userService ?? (_defaultUserService ??= UserService());
  AuthService get _authService =>
      widget.authService ?? (_defaultAuthService ??= AuthService());

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final grades = List<Grade>.of(await _gradeService.loadActiveGrades())
        ..sort((first, second) => first.order.compareTo(second.order));
      if (!mounted) return;
      setState(() {
        _grades = List.unmodifiable(grades);
        _isLoading = false;
        _loadError = null;
      });
    } on GradeFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحميل الصفوف الدراسية. حاول مرة أخرى.';
      });
    }
  }

  Future<void> _confirmSelection() async {
    if (_isSaving || _selectionCompleted) return;

    final gradeId = _selectedGradeId;
    if (gradeId == null) {
      _showMessage('يرجى اختيار الصف الدراسي.');
      return;
    }

    final uid = _authService.currentUserUid;
    if (uid == null || uid.isEmpty) {
      _showMessage('تعذر التحقق من جلسة المستخدم. سجل الدخول مرة أخرى.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _userService.selectGrade(uid: uid, gradeId: gradeId);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _selectionCompleted = true;
      });
      _showMessage('تم حفظ صفك الدراسي بنجاح.', isSuccess: true);
    } on UserGradeSelectionFailure catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('تعذر حفظ الصف الدراسي. حاول مرة أخرى.');
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? AppTheme.success : AppTheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.textPrimary.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(child: AppLogo(width: 88)),
                          const SizedBox(height: 18),
                          const Text(
                            'اختر صفك الدراسي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'اختر الصف الذي تنتمي إليه لمتابعة محتواك التعليمي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _buildContent(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _LoadingState(key: ValueKey('loading'));
    }

    final loadError = _loadError;
    if (loadError != null) {
      return _LoadErrorState(
        key: const ValueKey('load-error'),
        message: loadError,
        onRetry: _loadGrades,
      );
    }

    if (_grades.isEmpty) {
      return const _EmptyState(key: ValueKey('empty'));
    }

    return Column(
      key: const ValueKey('grades'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _grades.length; index++) ...[
          _GradeOption(
            grade: _grades[index],
            isSelected: _selectedGradeId == _grades[index].gradeId,
            isEnabled: !_isSaving && !_selectionCompleted,
            onSelected: () {
              setState(() => _selectedGradeId = _grades[index].gradeId);
            },
          ),
          if (index != _grades.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
        if (_selectionCompleted) ...[
          const _SuccessState(),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 56,
          child: ElevatedButton(
            key: const Key('confirm-grade-button'),
            onPressed:
                _selectedGradeId == null || _isSaving || _selectionCompleted
                ? null
                : _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.card,
              shape: const StadiumBorder(),
              elevation: 3,
              shadowColor: AppTheme.primary.withValues(alpha: 0.24),
            ),
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.card,
                    ),
                  )
                : const Text(
                    'تأكيد الاختيار',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
          ),
        ),
      ],
    );
  }
}

class _GradeOption extends StatelessWidget {
  const _GradeOption({
    required this.grade,
    required this.isSelected,
    required this.isEnabled,
    required this.onSelected,
  });

  final Grade grade;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppTheme.primaryLight : AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.textSecondary.withValues(alpha: 0.24),
            width: isSelected ? 1.7 : 1,
          ),
        ),
        child: InkWell(
          key: Key('grade-option-${grade.gradeId}'),
          onTap: isEnabled ? onSelected : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: AppTheme.primary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    grade.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text(
            'جارٍ تحميل الصفوف الدراسية...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.error,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const Key('retry-grades-button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.school_outlined, color: AppTheme.textSecondary, size: 42),
          SizedBox(height: 12),
          Text(
            'لا توجد صفوف دراسية متاحة حالياً.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('grade-selection-success'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.28)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.success),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'تم حفظ صفك الدراسي بنجاح.',
              style: TextStyle(
                color: AppTheme.success,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
