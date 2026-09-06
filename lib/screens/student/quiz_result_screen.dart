import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/question.dart';
import '../../services/quiz_service.dart';
import '../../widgets/app_logo.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    super.key,
    required this.questions,
    required this.selectedAnswerIndexes,
    required this.evaluation,
  });

  final List<Question> questions;
  final Map<String, int> selectedAnswerIndexes;
  final QuizEvaluationResult evaluation;

  String get _percentageLabel {
    final percentage = evaluation.attempt.percentage;
    return percentage == percentage.roundToDouble()
        ? percentage.toStringAsFixed(0)
        : percentage.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      key: const Key('quiz-result-directionality'),
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              const _ResultHeader(),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('quiz-result-scroll-view'),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ScoreCard(
                            score: evaluation.attempt.score,
                            totalQuestions: evaluation.attempt.totalQuestions,
                            percentageLabel: _percentageLabel,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'مراجعة الإجابات',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var index = 0; index < questions.length; index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AnswerFeedbackCard(
                                questionNumber: index + 1,
                                question: questions[index],
                                selectedAnswerIndex:
                                    selectedAnswerIndexes[questions[index]
                                        .questionId]!,
                                isCorrect:
                                    evaluation
                                        .answerCorrectness[questions[index]
                                        .questionId] ??
                                    false,
                              ),
                            ),
                        ],
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.totalQuestions,
    required this.percentageLabel,
  });

  final int score;
  final int totalQuestions;
  final String percentageLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quiz-result-summary'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            color: AppTheme.primary,
            size: 44,
          ),
          const SizedBox(height: 10),
          const Text(
            'نتيجة الاختبار',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score من $totalQuestions',
            key: const Key('quiz-result-score'),
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$percentageLabel%',
            key: const Key('quiz-result-percentage'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerFeedbackCard extends StatelessWidget {
  const _AnswerFeedbackCard({
    required this.questionNumber,
    required this.question,
    required this.selectedAnswerIndex,
    required this.isCorrect,
  });

  final int questionNumber;
  final Question question;
  final int selectedAnswerIndex;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('quiz-feedback-${question.questionId}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCorrect ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
                color: isCorrect ? AppTheme.success : AppTheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'إجابة صحيحة' : 'إجابة غير صحيحة',
                style: TextStyle(
                  color: isCorrect ? AppTheme.success : AppTheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$questionNumber. ${question.questionText}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'إجابتك: ${question.options[selectedAnswerIndex]}',
            key: Key('quiz-selected-answer-${question.questionId}'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'الإجابة الصحيحة: ${question.options[question.correctAnswerIndex]}',
            key: Key('quiz-correct-answer-${question.questionId}'),
            style: const TextStyle(
              color: AppTheme.success,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'التفسير: ${question.explanation}',
            key: Key('quiz-explanation-${question.questionId}'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader();

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
            key: const Key('quiz-result-back-button'),
            tooltip: 'العودة إلى الدرس',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.textPrimary,
            ),
          ),
          const AppLogo(width: 46),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'نتيجة الاختبار',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
