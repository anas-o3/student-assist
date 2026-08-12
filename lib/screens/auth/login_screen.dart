import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_password_field.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                          const AppPasswordField(
                            hintText: 'أدخل كلمة المرور',
                            textInputAction: TextInputAction.done,
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
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
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: AppTheme.card,
                                shape: const StadiumBorder(),
                                elevation: 3,
                                shadowColor: AppTheme.primary.withValues(
                                  alpha: 0.24,
                                ),
                              ),
                              child: const Stack(
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
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Icon(Icons.login_rounded, size: 25),
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
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          const RegisterScreen(),
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
