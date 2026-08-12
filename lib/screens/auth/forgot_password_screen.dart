import 'package:flutter/material.dart';

import '../../app/theme.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

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
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 30),
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
                          Align(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mark_email_unread_outlined,
                                color: AppTheme.primary,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'استعادة كلمة المرور',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'أدخل بريدك الإلكتروني، وسنرسل لك رابطاً\n'
                            'لاستعادة كلمة المرور',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'البريد الإلكتروني',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const TextField(
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'example@school.edu',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 58,
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
                                      'إرسال رابط الاستعادة',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Icon(Icons.send_rounded, size: 22),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'العودة لتسجيل الدخول',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
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
