import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../widgets/app_logo.dart';

class LessonContentScreen extends StatelessWidget {
  const LessonContentScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      key: const Key('lesson-content-directionality'),
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _LessonContentHeader(title: lesson.title),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SingleChildScrollView(
                      key: const Key('lesson-content-scroll-view'),
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryLight),
                        ),
                        child: Text(
                          lesson.explanation,
                          key: const Key('lesson-explanation'),
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            height: 1.9,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonContentHeader extends StatelessWidget {
  const _LessonContentHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryLight, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('lesson-content-back-button'),
            tooltip: 'رجوع',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.textPrimary,
            ),
          ),
          const AppLogo(width: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              key: const Key('lesson-content-title'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
