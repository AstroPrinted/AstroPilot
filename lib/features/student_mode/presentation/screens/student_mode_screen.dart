import 'package:flutter/material.dart';

import '../../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../../space_education/presentation/screens/space_education_screen.dart';
import '../../data/student_quiz_repository.dart';
import '../../data/student_quiz_storage.dart';
import '../../domain/models/student_quiz_question.dart';
import '../controllers/student_quiz_controller.dart';

class StudentModeScreen extends StatefulWidget {
  final StudentQuizController? controller;

  const StudentModeScreen({super.key, this.controller});

  @override
  State<StudentModeScreen> createState() => _StudentModeScreenState();
}

class _StudentModeScreenState extends State<StudentModeScreen> {
  late final StudentQuizController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        StudentQuizController(
          quizRepository: StudentQuizRepository(
            catalogRepository: CelestialCatalogRepository(),
          ),
          storage: const StudentQuizStorage(),
        );
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modo educativo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _HubInfoCard(),
          const SizedBox(height: 14),
          _EducationHubCard(
            icon: Icons.quiz_rounded,
            title: 'Quiz astronómico',
            description:
                'Responde una tanda diaria de preguntas fáciles y medias con explicaciones breves.',
            onTap: _openQuiz,
          ),
          const SizedBox(height: 10),
          _EducationHubCard(
            icon: Icons.satellite_alt_rounded,
            title: 'Satélites y exploración espacial',
            description:
                'Lee fichas sobre la ISS, satélites artificiales, sondas y curiosidades. Funciona sin internet.',
            onTap: _openSpaceEducation,
          ),
        ],
      ),
    );
  }

  void _openQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StudentQuizScreen(controller: _controller),
      ),
    );
  }

  void _openSpaceEducation() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SpaceEducationScreen()));
  }
}

/// Quiz como pantalla independiente (pestaña Quiz del modo Educativo).
class StudentQuizPage extends StatefulWidget {
  final StudentQuizController? controller;
  final PreferredSizeWidget? appBar;

  const StudentQuizPage({super.key, this.controller, this.appBar});

  @override
  State<StudentQuizPage> createState() => _StudentQuizPageState();
}

class _StudentQuizPageState extends State<StudentQuizPage> {
  late final StudentQuizController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        StudentQuizController(
          quizRepository: StudentQuizRepository(
            catalogRepository: CelestialCatalogRepository(),
          ),
          storage: const StudentQuizStorage(),
        );
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StudentQuizScreen(controller: _controller, appBar: widget.appBar);
}

class _StudentQuizScreen extends StatelessWidget {
  final StudentQuizController controller;
  final PreferredSizeWidget? appBar;

  const _StudentQuizScreen({required this.controller, this.appBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ?? AppBar(title: const Text('Quiz astronómico')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = controller.errorMessage;
          if (error != null) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              title: 'No se pudo cargar el quiz',
              message: error,
              actionLabel: 'Reintentar',
              onAction: controller.load,
            );
          }

          if (!controller.hasQuestions) {
            return const _CenteredMessage(
              icon: Icons.school_outlined,
              title: 'Sin preguntas',
              message: 'No hay preguntas disponibles para hoy.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _DailySummaryCard(controller: controller),
              const SizedBox(height: 14),
              if (controller.currentQuestion == null)
                _DailyLimitCard(controller: controller)
              else
                _QuestionCard(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

class _HubInfoCard extends StatelessWidget {
  const _HubInfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.school_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Aprende astronomía y exploración espacial desde secciones educativas. Estas tarjetas no controlan el telescopio ni envían comandos.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EducationHubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _EducationHubCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(description),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  final StudentQuizController controller;

  const _DailySummaryCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress =
        controller.answeredToday / StudentQuizController.dailyLimit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quiz astronómico',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: progress.clamp(0, 1)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Preguntas de hoy',
                    value:
                        '${controller.answeredToday}/${StudentQuizController.dailyLimit}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Aciertos',
                    value:
                        '${controller.correctToday}/${controller.answeredToday}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyLimitCard extends StatelessWidget {
  final StudentQuizController controller;

  const _DailyLimitCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined, color: colorScheme.primary, size: 36),
            const SizedBox(height: 12),
            Text(
              'Meta diaria completada',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Respondida la tanda de 5 preguntas. Vuelve mañana para una nueva ronda.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _MetricTile(
              label: 'Resultado de hoy',
              value:
                  '${controller.correctToday}/${StudentQuizController.dailyLimit} aciertos',
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final StudentQuizController controller;

  const _QuestionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final question = controller.currentQuestion!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QuestionMeta(question: question),
            const SizedBox(height: 12),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < question.choices.length; i++) ...[
              _ChoiceButton(
                question: question,
                index: i,
                selectedIndex: controller.selectedChoiceIndex,
                answerSubmitted: controller.answerSubmitted,
                onPressed: () => controller.answerChoice(i),
              ),
              const SizedBox(height: 8),
            ],
            if (controller.answerSubmitted) ...[
              const SizedBox(height: 8),
              _AnswerFeedback(controller: controller, question: question),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.goToNextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  controller.isDailyLimitReached
                      ? 'Ver resumen de hoy'
                      : 'Siguiente pregunta',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionMeta extends StatelessWidget {
  final StudentQuizQuestion question;

  const _QuestionMeta({required this.question});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(
          icon: Icons.speed_rounded,
          label: question.difficulty.label,
          color: colorScheme.primary,
        ),
        _Pill(
          icon: Icons.auto_awesome_rounded,
          label: question.topic,
          color: colorScheme.secondary,
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final StudentQuizQuestion question;
  final int index;
  final int? selectedIndex;
  final bool answerSubmitted;
  final VoidCallback onPressed;

  const _ChoiceButton({
    required this.question,
    required this.index,
    required this.selectedIndex,
    required this.answerSubmitted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCorrect = index == question.correctIndex;
    final isSelected = index == selectedIndex;
    final showCorrect = answerSubmitted && isCorrect;
    final showWrong = answerSubmitted && isSelected && !isCorrect;
    final borderColor = showCorrect
        ? Colors.green
        : showWrong
        ? colorScheme.error
        : colorScheme.outlineVariant;
    final background = showCorrect
        ? Colors.green.withValues(alpha: 0.12)
        : showWrong
        ? colorScheme.error.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final icon = showCorrect
        ? Icons.check_circle_outline_rounded
        : showWrong
        ? Icons.cancel_outlined
        : Icons.radio_button_unchecked_rounded;

    return OutlinedButton(
      onPressed: answerSubmitted ? null : onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        disabledForegroundColor: colorScheme.onSurface,
        side: BorderSide(color: borderColor),
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(question.choices[index])),
        ],
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  final StudentQuizController controller;
  final StudentQuizQuestion question;

  const _AnswerFeedback({required this.controller, required this.question});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCorrect = controller.lastAnswerCorrect ?? false;
    final color = isCorrect ? Colors.green : colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCorrect ? 'Respuesta correcta' : 'Respuesta incorrecta',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(question.explanation),
          if (controller.currentObjectNote != null) ...[
            const SizedBox(height: 10),
            Text(
              'Curiosidad: ${controller.currentObjectNote}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
