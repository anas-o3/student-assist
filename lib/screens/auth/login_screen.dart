import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../screens/student/grade_selection_screen.dart';
import '../../screens/student/student_home_screen.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_password_field.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

typedef GradeSelectionScreenBuilder = Widget Function();
typedef StudentHomeScreenBuilder = Widget Function(String gradeId);

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authService,
    this.userService,
    this.gradeSelectionScreenBuilder,
    this.studentHomeScreenBuilder,
  });

  final AuthService? authService;
  final UserService? userService;
  final GradeSelectionScreenBuilder? gradeSelectionScreenBuilder;
  final StudentHomeScreenBuilder? studentHomeScreenBuilder;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthService? _defaultAuthService;
  UserService? _defaultUserService;
  bool _isLoading = false;
  bool _hasNavigated = false;

  AuthService get _authService =>
      widget.authService ?? (_defaultAuthService ??= AuthService());
  UserService get _userService =>
      widget.userService ?? (_defaultUserService ??= UserService());

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('يرجى إدخال البريد الإلكتروني وكلمة المرور.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(email: email, password: password);
      if (!mounted) return;

      final uid = _authService.currentUserUid;
      if (uid == null || uid.trim().isEmpty) {
        _showMessage('تعذر التحقق من جلسة المستخدم. سجل الدخول مرة أخرى.');
        return;
      }

      final profile = await _userService.getUserProfile(uid);
      if (!mounted) return;

      switch (_userService.decidePostLoginRoute(profile)) {
        case PostLoginRoute.studentNeedsGradeSelection:
          _replaceLoginWith(_buildGradeSelectionScreen());
        case PostLoginRoute.studentReady:
          _replaceLoginWith(_buildStudentHomeScreen(profile.gradeId!));
        case PostLoginRoute.admin:
          _showMessage('تم تسجيل الدخول، لكن واجهة الإدارة غير متاحة حالياً.');
        case PostLoginRoute.invalidRole:
          _showMessage('تعذر تحديد صلاحية الحساب. تواصل مع إدارة التطبيق.');
      }
    } on AuthFailure catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } on UserProfileFailure catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر إكمال العملية. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGradeSelectionScreen() {
    return widget.gradeSelectionScreenBuilder?.call() ??
        GradeSelectionScreen(studentHomeScreenBuilder: _buildStudentHomeScreen);
  }

  Widget _buildStudentHomeScreen(String gradeId) {
    return widget.studentHomeScreenBuilder?.call(gradeId) ??
        StudentHomeScreen(gradeId: gradeId);
  }

  void _replaceLoginWith(Widget destination) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => destination),
      (_) => false,
    );
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
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.fromLTRB(32, 48, 32, 30),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
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
                          const Align(child: AppLogo(width: 112)),
                          const SizedBox(height: 20),
                          const Text(
                            'مساعد طلبة الثانوية',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'مرحباً بعودتك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'سجل دخولك لمتابعة دراستك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 31),
                          const _FieldLabel('البريد الإلكتروني'),
                          const SizedBox(height: 7),
                          TextField(
                            controller: _emailController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              hintText: 'أدخل بريدك الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 21),
                          const _FieldLabel('كلمة المرور'),
                          const SizedBox(height: 7),
                          AppPasswordField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            hintText: 'أدخل كلمة المرور',
                            textInputAction: TextInputAction.done,
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (context) =>
                                              ForgotPasswordScreen(
                                                authService: widget.authService,
                                              ),
                                        ),
                                      );
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'نسيت كلمة المرور؟',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: AppTheme.card,
                                shape: const StadiumBorder(),
                                elevation: 3,
                                shadowColor: AppTheme.primary.withValues(
                                  alpha: 0.24,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox.square(
                                      dimension: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppTheme.card,
                                      ),
                                    )
                                  : const Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Center(
                                          child: Text(
                                            'تسجيل الدخول',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment:
                                              AlignmentDirectional.centerEnd,
                                          child: Icon(
                                            Icons.login_rounded,
                                            size: 25,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'ليس لديك حساب؟',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (context) =>
                                                RegisterScreen(
                                                  authService:
                                                      widget.authService,
                                                ),
                                          ),
                                        );
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'إنشاء حساب جديد',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
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
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
