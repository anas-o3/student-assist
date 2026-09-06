import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../models/question.dart';
import '../../services/auth_service.dart';
import '../../services/quiz_service.dart';
import '../../widgets/app_logo.dart';
import 'quiz_result_screen.dart';

typedef QuizResultScreenBuilder =
    Widget Function({
      required List<Question> questions,
      required Map<String, int> selectedAnswerIndexes,
      required QuizEvaluationResult evaluation,
    });

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.lesson,
    this.quizService,
    this.authService,
    this.resultScreenBuilder,
  });

  final Lesson lesson;
  final QuizService? quizService;
  final AuthService? authService;
  final QuizResultScreenBuilder? resultScreenBuilder;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizService? _defaultQuizService;
  AuthService? _defaultAuthService;
  List<Question> _questions = const [];
  final Map<String, int> _selectedAnswerIndexes = {};
  String? _loadError;
  String? _submissionError;
  var _currentQuestionIndex = 0;
  var _isLoading = true;
  var _isSubmitting = false;
  var _submissionLocked = false;
  var _submissionCompleted = false;

  QuizService get _quizService =>
      widget.quizService ?? (_defaultQuizService ??= QuizService());
  AuthService get _authService =>
      widget.authService ?? (_defaultAuthService ??= AuthService());

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final questions = List<Question>.of(
        await _quizService.loadActiveQuestionsForLesson(widget.lesson.lessonId),
      )..sort((first, second) => first.order.compareTo(second.order));
      if (!mounted) return;
      setState(() {
        _questions = List.unmodifiable(questions);
        _selectedAnswerIndexes.clear();
        _currentQuestionIndex = 0;
        _isLoading = false;
        _loadError = null;
        _submissionError = null;
        _submissionLocked = false;
      });
    } on QuizFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحميل أسئلة الاختبار. حاول مرة أخرى.';
      });
    }
  }

  void _selectAnswer(int answerIndex) {
    if (_isSubmitting || _submissionLocked || _submissionCompleted) return;
    final question = _questions[_currentQuestionIndex];
    setState(() {
      _selectedAnswerIndexes[question.questionId] = answerIndex;
      _submissionError = null;
    });
  }

  void _moveToNextQuestion() {
    final question = _questions[_currentQuestionIndex];
    if (!_selectedAnswerIndexes.containsKey(question.questionId)) {
      _showMessage('يرجى اختيار إجابة قبل المتابعة.');
      return;
    }
    setState(() => _currentQuestionIndex++);
  }

  void _moveToPreviousQuestion() {
    if (_currentQuestionIndex == 0 || _isSubmitting) return;
    setState(() => _currentQuestionIndex--);
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _submissionLocked || _submissionCompleted) return;
    if (_selectedAnswerIndexes.length != _questions.length) {
      _showMessage('يرجى الإجابة عن جميع أسئلة الاختبار.');
      return;
    }

    final userId = _authService.currentUserUid;
    if (userId == null || userId.trim().isEmpty) {
      _showMessage('تعذر التحقق من جلسة المستخدم. سجل الدخول مرة أخرى.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final evaluation = await _quizService.evaluateAndSaveAttempt(
        userId: userId,
        lessonId: widget.lesson.lessonId,
        questions: _questions,
        selectedAnswerIndexes: Map.unmodifiable(_selectedAnswerIndexes),
      );
      if (!mounted || _submissionCompleted) return;
      setState(() {
        _isSubmitting = false;
        _submissionCompleted = true;
      });

      final resultScreen =
          widget.resultScreenBuilder?.call(
            questions: _questions,
            selectedAnswerIndexes: Map.unmodifiable(_selectedAnswerIndexes),
            evaluation: evaluation,
          ) ??
          QuizResultScreen(
            questions: _questions,
            selectedAnswerIndexes: Map.unmodifiable(_selectedAnswerIndexes),
            evaluation: evaluation,
          );
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: (_) => resultScreen),
      );
    } on QuizFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submissionLocked = error.reason == QuizFailureReason.saveFailed;
        _submissionError = error.reason == QuizFailureReason.saveFailed
            ? 'تعذر التأكد من حفظ النتيجة. ارجع إلى الدرس ثم أعد فتح الاختبار.'
            : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submissionLocked = true;
        _submissionError =
            'تعذر التأكد من حفظ النتيجة. ارجع إلى الدرس ثم أعد فتح الاختبار.';
      });
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      key: const Key('quiz-directionality'),
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _QuizHeader(title: widget.lesson.title),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _QuizLoadingState(key: ValueKey('quiz-loading'));
    }
    final loadError = _loadError;
    if (loadError != null) {
      return _QuizLoadErrorState(
        key: const ValueKey('quiz-load-error'),
        message: loadError,
        onRetry: _loadQuestions,
      );
    }
    if (_questions.isEmpty) {
      return const _QuizEmptyState(key: ValueKey('quiz-empty'));
    }

    final question = _questions[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;
    return SingleChildScrollView(
      key: const ValueKey('quiz-question-content'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
                key: const Key('quiz-question-progress'),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _questions.length,
                color: AppTheme.primary,
                backgroundColor: AppTheme.primaryLight,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      question.questionText,
                      key: Key('quiz-question-${question.questionId}'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (
                      var index = 0;
                      index < question.options.length;
                      index++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnswerOption(
                          key: Key('quiz-option-${question.questionId}-$index'),
                          label: question.options[index],
                          selected:
                              _selectedAnswerIndexes[question.questionId] ==
                              index,
                          enabled: !_isSubmitting && !_submissionLocked,
                          onTap: () => _selectAnswer(index),
                        ),
                      ),
                  ],
                ),
              ),
              if (_submissionError case final message?) ...[
                const SizedBox(height: 14),
                Text(
                  message,
                  key: const Key('quiz-submission-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_currentQuestionIndex > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('quiz-previous-button'),
                        onPressed: _isSubmitting
                            ? null
                            : _moveToPreviousQuestion,
                        child: const Text('السابق'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: _currentQuestionIndex > 0 ? 1 : 2,
                    child: ElevatedButton(
                      key: Key(
                        isLastQuestion
                            ? 'quiz-submit-button'
                            : 'quiz-next-button',
                      ),
                      onPressed: _isSubmitting || _submissionLocked
                          ? null
                          : isLastQuestion
                          ? _submitQuiz
                          : _moveToNextQuestion,
                      child: _isSubmitting
                          ? const SizedBox(
                              key: Key('quiz-submit-progress'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(isLastQuestion ? 'إرسال الإجابات' : 'التالي'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primaryLight : AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.4,
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

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.title});

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
            key: const Key('quiz-back-button'),
            tooltip: 'رجوع',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.textPrimary,
            ),
          ),
          const AppLogo(width: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'اختبار: $title',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizLoadingState extends StatelessWidget {
  const _QuizLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 14),
          Text(
            'جارٍ تحميل أسئلة الاختبار...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _QuizLoadErrorState extends StatelessWidget {
  const _QuizLoadErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.error,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('quiz-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizEmptyState extends StatelessWidget {
  const _QuizEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'لا توجد أسئلة متاحة لهذا الدرس حاليًا.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
